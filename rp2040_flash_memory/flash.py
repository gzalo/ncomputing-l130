from machine import Pin, SPI
import time

# RP2040 / Pico        AT45DB041D
# 3V3                 VCC
# GND                 GND
# GP18 SPI0 SCK       SCK
# GP19 SPI0 TX/MOSI   SI
# GP16 SPI0 RX/MISO   SO
# GP17 GPIO           /CS
# 3V3                 /WP  pulled high
# 3V3                 /RESET pulled high

spi = SPI(
    0,
    baudrate=1_000_000,
    polarity=0,
    phase=0,
    bits=8,
    firstbit=SPI.MSB,
    sck=Pin(18),
    mosi=Pin(19),
    miso=Pin(16),
)

cs = Pin(17, Pin.OUT, value=1)

def xfer(tx, rx_len=0):
    """
    Send arbitrary bytes to the AT45DB041D.
    Returns bytes read during optional dummy clocks.
    """
    cs.value(0)
    time.sleep_us(1)

    if tx:
        spi.write(bytes(tx))

    rx = b""
    if rx_len:
        rx = spi.read(rx_len, 0x00)

    time.sleep_us(1)
    cs.value(1) 
    return rx

# AT45DB041D helpers for 256-byte page mode

PAGE_SIZE = 256
NUM_PAGES = 2048          # AT45DB041D: 4 Mbit / 256 bytes = 2048 pages
TOTAL_SIZE = PAGE_SIZE * NUM_PAGES

CMD_STATUS = 0xD7
CMD_BUF1_WRITE = 0x84
CMD_BUF1_TO_PAGE_ERASE = 0x83
CMD_ARRAY_READ_LOW_FREQ = 0x03


def status():
    return xfer([CMD_STATUS], 1)[0]


def wait_ready(verbose=False):
    while True:
        s = status()
        if verbose:
            print("status:", hex(s))
        if s & 0x80:
            return s


def addr24(addr):
    return [
        (addr >> 16) & 0xFF,
        (addr >> 8) & 0xFF,
        addr & 0xFF,
    ]


def page_addr(page, byte_offset=0):
    """
    In 256-byte page mode, the address is linear:
        addr = page * 256 + byte_offset
    """
    if page < 0 or page >= NUM_PAGES:
        raise ValueError("page out of range")
    if byte_offset < 0 or byte_offset >= PAGE_SIZE:
        raise ValueError("byte offset out of range")

    return page * PAGE_SIZE + byte_offset


def buffer1_write(data, offset=0):
    """
    Write up to 256 bytes into SRAM Buffer 1.
    This does not touch flash yet.
    """
    if offset < 0 or offset >= PAGE_SIZE:
        raise ValueError("buffer offset out of range")
    if len(data) + offset > PAGE_SIZE:
        raise ValueError("data too large for buffer")

    # Buffer write command uses 3 address bytes.
    # In practice, for buffer write, only the low byte offset matters in binary mode.
    cmd = [CMD_BUF1_WRITE, 0x00, 0x00, offset & 0xFF]
    xfer(cmd + list(data))


def buffer1_to_page_with_erase(page):
    """
    Program Buffer 1 into main memory page using built-in erase.
    """
    a = page_addr(page, 0)
    xfer([CMD_BUF1_TO_PAGE_ERASE] + addr24(a))
    wait_ready()


def read_array(addr, length):
    """
    Read arbitrary bytes from main memory using low-frequency continuous array read.
    """
    if addr < 0 or addr + length > TOTAL_SIZE:
        raise ValueError("read out of range")

    return xfer([CMD_ARRAY_READ_LOW_FREQ] + addr24(addr), length)


def read_page(page):
    return read_array(page_addr(page), PAGE_SIZE)


def program_page(page, data, pad=True, verify=True):
    """
    Program one 256-byte page.

    If pad=True, shorter pages are padded with 0xFF.
    """
    if len(data) > PAGE_SIZE:
        raise ValueError("page data too large")

    if len(data) < PAGE_SIZE:
        if not pad:
            raise ValueError("page data must be exactly 256 bytes")
        data = data + bytes([0xFF]) * (PAGE_SIZE - len(data))

    wait_ready()

    buffer1_write(data)
    buffer1_to_page_with_erase(page)

    if verify:
        rb = read_page(page)
        if rb != data:
            # Find first mismatch for debugging
            for i, (a, b) in enumerate(zip(data, rb)):
                if a != b:
                    raise RuntimeError(
                        "verify failed at page {}, offset 0x{:02X}: expected 0x{:02X}, got 0x{:02X}".format(
                            page, i, a, b
                        )
                    )
            raise RuntimeError("verify failed at page {}".format(page))

    return True


def program_file(filename, start_page=0, verify=True, max_pages=None):
    """
    Program flash pages from a file stored on the RP2040 filesystem.

    Example:
        program_file("firmware.bin", start_page=0)

    The last partial page is padded with 0xFF.
    """
    page = start_page
    written = 0

    if start_page < 0 or start_page >= NUM_PAGES:
        raise ValueError("start_page out of range")

    with open(filename, "rb") as f:
        while True:
            if max_pages is not None and written >= max_pages:
                break

            chunk = f.read(PAGE_SIZE)
            if not chunk:
                break

            if page >= NUM_PAGES:
                raise RuntimeError("file does not fit in flash")

            print("programming page", page, "file offset", written * PAGE_SIZE)
            program_page(page, chunk, pad=True, verify=verify)

            page += 1
            written += 1

    print("done:", written, "pages,", written * PAGE_SIZE, "bytes allocated in flash")
    return written


CMD_ARRAY_READ_HIGH_FREQ = 0x0B

def read_array_hf(addr, length):
    """
    Continuous Array Read, High Frequency Mode, opcode 0x0B.

    Command format:
        0B A2 A1 A0 00 -> data...
    """
    if addr < 0 or addr + length > TOTAL_SIZE:
        raise ValueError("read out of range")

    # opcode + 24-bit address + one dummy byte
    return xfer([CMD_ARRAY_READ_HIGH_FREQ] + addr24(addr) + [0x00], length)


def verify_file_hf(filename, start_page=0, max_pages=None, chunk_size=256):
    """
    Compare a file stored on the RP2040 filesystem against flash contents,
    using Continuous Array Read High Frequency Mode, opcode 0x0B.

    The last partial page is compared against file bytes only.
    It does not require the padded 0xFF bytes to match unless verify_padding=True
    is added separately.
    """
    start_addr = start_page * PAGE_SIZE
    file_offset = 0
    total_checked = 0

    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")

    if start_addr >= TOTAL_SIZE:
        raise ValueError("start_page out of range")

    with open(filename, "rb") as f:
        while True:
            if max_pages is not None and file_offset >= max_pages * PAGE_SIZE:
                break

            remaining_limit = None
            if max_pages is not None:
                remaining_limit = max_pages * PAGE_SIZE - file_offset
                if remaining_limit <= 0:
                    break

            to_read = chunk_size
            if remaining_limit is not None and to_read > remaining_limit:
                to_read = remaining_limit

            expected = f.read(to_read)
            if not expected:
                break

            addr = start_addr + file_offset
            if addr + len(expected) > TOTAL_SIZE:
                raise RuntimeError("file extends past end of flash")

            actual = read_array_hf(addr, len(expected))

            if actual != expected:
                # Find first mismatch inside this chunk
                for i, (e, a) in enumerate(zip(expected, actual)):
                    if e != a:
                        absolute = file_offset + i
                        flash_addr = addr + i
                        page = flash_addr // PAGE_SIZE
                        page_off = flash_addr % PAGE_SIZE

                        print("VERIFY FAILED")
                        print("file offset: 0x{:06X}".format(absolute))
                        print("flash addr:  0x{:06X}".format(flash_addr))
                        print("page:        {}".format(page))
                        print("page offset: 0x{:02X}".format(page_off))
                        print("expected:    0x{:02X}".format(e))
                        print("actual:      0x{:02X}".format(a))

                        # Print a small context window
                        ctx_start = max(0, i - 8)
                        ctx_end = min(len(expected), i + 8)

                        print("expected context:",
                              " ".join("{:02X}".format(x) for x in expected[ctx_start:ctx_end]))
                        print("actual context:  ",
                              " ".join("{:02X}".format(x) for x in actual[ctx_start:ctx_end]))

                        return False

                print("VERIFY FAILED, but mismatch location not found?")
                return False

            total_checked += len(expected)
            file_offset += len(expected)

            if total_checked % 4096 == 0:
                print("verified", total_checked, "bytes")

    print("verify OK:", total_checked, "bytes")
    return True


