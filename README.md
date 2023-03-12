# Pulpino Top-Level CW305

## Wire Definitions

### `GPIO_IN`

```
[11]:  ext_read_flicker
[10]:  ext_write_flicker
[9]:   usb_read_flicker
[8]:   usb_write_flicker
[7:0]: data
```

### `GPIO_OUT`

```
[11]:  pulpino_usb_read_flicker
[10]:  pulpino_usb_write_flicker
[9]:   pulpino_ext_read_flicker
[8]:   pulpino_ext_write_flicker
[7:0]: data
```

## Protocol Definitions

### USB <> Pulpino

```python
def pulpino_usb_read():
    word = 0

    for i in range(4):
        await usb_write_flicker != (i & 1)

        word <<= 8
        word |= data

        pulpino_usb_read_flicker = !(i & 1)
    
    return word
```

```python
def pulpino_usb_write(word):
    for i in range(4):
        data = word & 0xFF
        word >>= 8

        pulpino_usb_write_flicker = !(i & 1)

        await usb_read_flicker != (i & 1)

    data = 0x00;
```

### External <> Pulpino

```python
def pulpino_ext_read():
    await ext_write_flicker != 1

    word = pulpino_usb_read()

    pulpino_ext_read_flicker = 1
    await ext_write_flicker != 0
    pulpino_ext_read_flicker = 0

    return word
```

```python
def pulpino_ext_write(word):
    pulpino_usb_write(word)

    pulpino_ext_write_flicker = 1
    await ext_read_flicker != 0
    pulpino_ext_write_flicker = 0
```

## TODO

- [x] Rename registers in `cw305_defines.v`
- [x] Remove many of the unused parts in `cw305_*.v` files
- [ ] Create Python files
- [ ] Create C files
- [ ] Create Rust files