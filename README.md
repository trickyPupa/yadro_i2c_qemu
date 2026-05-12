# I2C устройство для QEMU

Автор: Лабор Тимофей Владимирович

## Задание

Цель задания — разработать простое I2C-устройство для QEMU, продемонстрировать навыки работы с низкоуровневым кодом, эмуляцией железа и интеграцией между гостевой системой и хостом через QMP.

Полный текст задания: [test_task_vPlatform.pdf](docs/test_task_vPlatform.pdf).

## Сборка и запуск

**Сборка и запуск предполагают использование операционной системы Linux.**

Установка необходимых библиотек.

Ubuntu/Debian:
```sh
sudo apt install -y python3 ninja-build libglib2.0-dev libpixman-1-dev libfdt-dev libncurses-dev zlib1g-dev cpio rsync bc flex bison i2c-tools
```

Fedora:
```sh
sudo dnf install -y python3 ninja-build glib2-devel pixman-devel libfdt-devel ncurses-devel zlib-devel cpio rsync bc flex bison i2c-tools
```

Для начала нужно клонировать репозиторий qemu и сконфигурировать сборку.
```sh
make setup
```

Для запуска требуются образы ядра Linux и файловой системы. Их собираем с помощью команд ниже (может занимать от 15 минут), после чего они появятся в `images/`. 
```sh
chmod +x ./build-images.sh
./build-images.sh
```

Сборка QEMU:
```sh
make build
```

Запуск QEMU:
```sh
make run
```

После сборки QEMU в терминале предложит ввести login, вводим `root`.

Для запуска программы, которая через QMP считывает значение регистра I2C-устройства:
```sh
python3 qmp_monitor.py
```

## Демонстрация работоспособности

![Работа монитора устройства](docs/i2c_device_monitoring.gif)

Вывод QEMU:
```
# i2cdetect -y 0
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- -- 
10: 10 -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- -- 
70: -- -- -- -- -- -- -- --                         

# i2cget -y 0 0x10
0x00
# i2cset -y 0 0x10 0x0b
# i2cget -y 0 0x10
0x0b
# i2cset -y 0 0x10 0x54
# i2cget -y 0 0x10
0x54
```

Вывод скрипта qmp_monitor.py:
```
$ python3 qmp_monitor.py 
Register value: 11
Register value: 11
Register value: 11
Register value: 11
Register value: 11
Register value: 11
Register value: 11
Register value: 84
Register value: 84
Register value: 84
Register value: 84
Register value: 84
Register value: 84
```

## Детали реализации

### Устройство 

Исходный код устройства находится в [src/i2c_device.c](src/i2c_device.c):
```c
#include "qemu/osdep.h"
#include "qemu/module.h"
#include "hw/i2c/i2c.h"

#define TYPE_YADRO_I2C_DEVICE "yadro-i2c-device"
OBJECT_DECLARE_SIMPLE_TYPE(YadroI2CState, YADRO_I2C_DEVICE)

struct YadroI2CState
{
    I2CSlave parent_obj;

    uint8_t reg;
};

static int yadro_i2c_event(I2CSlave *s, enum i2c_event event)
{
    switch (event)
    {
    case I2C_START_RECV:
    case I2C_START_SEND:
    case I2C_FINISH:
    case I2C_NACK:
        return 0;
    default:
        return -1;
    }
}

static uint8_t yadro_i2c_recv(I2CSlave *s)
{
    YadroI2CState *state = YADRO_I2C_DEVICE(s);

    return state->reg;
}

static int yadro_i2c_send(I2CSlave *s, uint8_t data)
{
    YadroI2CState *state = YADRO_I2C_DEVICE(s);

    state->reg = data;
    return 0;
}

static void yadro_i2c_reset(DeviceState *dev)
{
    YadroI2CState *state = YADRO_I2C_DEVICE(dev);

    state->reg = 0;
}

static void yadro_i2c_instance_init(Object *obj)
{
    YadroI2CState *state = YADRO_I2C_DEVICE(obj);
    object_property_add_uint8_ptr(obj, "reg", &state->reg,
                                  OBJ_PROP_FLAG_READWRITE);
}

static void yadro_i2c_class_init(ObjectClass *oc, const void *data)
{
    I2CSlaveClass *sc = I2C_SLAVE_CLASS(oc);
    DeviceClass *dc = DEVICE_CLASS(oc);

    // для совместимости с QMP
    device_class_set_legacy_reset(dc, yadro_i2c_reset);

    sc->event = yadro_i2c_event;
    sc->recv = yadro_i2c_recv;
    sc->send = yadro_i2c_send;
}

static const TypeInfo yadro_i2c_type_info = {
    .name = TYPE_YADRO_I2C_DEVICE,
    .parent = TYPE_I2C_SLAVE,
    .instance_size = sizeof(YadroI2CState),
    .instance_init = yadro_i2c_instance_init,
    .class_init = yadro_i2c_class_init,
};

static void yadro_i2c_register_types(void)
{
    type_register_static(&yadro_i2c_type_info);
}

type_init(yadro_i2c_register_types);
```

Так как кода совсем немного, было решено объединить все объявления и реализацию в один файл `.c`.

### Запуск и сборка

Запуск и сборка проекта выполняются с помощью утилиты Make; реализация целей сборки - в [Makefile](Makefile).
Запуск QEMU:
```make
ROOT_DIR := $(CURDIR)
QEMU_DIR := $(ROOT_DIR)/qemu
BUILD_DIR := $(QEMU_DIR)/build
QEMU_BIN_ARM := $(BUILD_DIR)/qemu-system-arm
IMAGES_DIR := $(ROOT_DIR)/images
I2C_ADDR ?= 0x10

...

run: build
	@"$(QEMU_BIN_ARM)" \
		-M versatilepb \
		-kernel $(IMAGES_DIR)/zImage \
		-dtb $(IMAGES_DIR)/versatile-pb.dtb \
		-append "root=/dev/sda console=ttyAMA0,115200" \
		-drive file=$(IMAGES_DIR)/rootfs.ext2,if=scsi,format=raw \
		-nographic \
		-device yadro-i2c-device,address=$(I2C_ADDR),bus=i2c,id=yadro-i2c \
		-qmp unix:/tmp/qmp.sock,server,nowait
```

Параметры запуска QEMU:

- `-M versatilepb` - Выбирает платформы для эмуляции: ARM board Versatile/PB. Без этого QEMU нечего будет эмулировать.
- `-kernel $(IMAGES_DIR)/zImage` - Напрямую загружает Linux-ядро. Нужно для запуска Linux в QEMU.
- `-dtb $(IMAGES_DIR)/versatile-pb.dtb` - Передаёт ядру описание устройств/шин/адресов для выбранной машины. Так как ядро собирается самостоятельно, конфигурация может быть нестандартной.
- `-append "root=/dev/sda console=ttyAMA0,115200"` - Передаёт параметры командной строки ядра.
    - `root=/dev/sda` - указывает, где находится корневая файловая система.
    - `console=ttyAMA0,115200` - показывает куда выводить консоль (нужно в `nographic` режиме), без этого не будет ввода и вывода.
- `-drive file=$(IMAGES_DIR)/rootfs.ext2,format=raw` - Подключает образ диска с rootfs (`rootfs.ext2`). `format=raw` — явно указывает формат образа, если убрать возникнет предупреждение от QEMU.
- `-nographic` - Отключает графическое окно и перенаправляет стандартные IO устройства в консоль, удобно для запуска в терминале.
- `-device yadro-i2c-device,address=$(I2C_ADDR),bus=i2c,id=yadro-i2c` - Добавляет I2C-устройство в конфигурацию машины. 
    - `address=$(I2C_ADDR)` - адрес устройства.
    - `bus=i2c` - имя шины, к которой подключается устройство.
    - `id=yadro-i2c` — QOM id устройства, используется при обращении в скрипте с QMP.
- `-qmp unix:/tmp/qmp.sock,server,nowait` - Включает QMP-монитор и поднимает сервер на UNIX-сокете `/tmp/qmp.sock`.
    - `server` — ожидает подключений к сокету.
    - `nowait` — не блокирует запуск, ожидая подключения.

I2C-шина предоставлена виртуальной машиной `versatilepb`. Есть ли она вообще и её название можно узнать при запуске QEMU и вводе команды `info qtree`. 
Устройство подключается к ней флагом `-device yadro-i2c-device,address=$(I2C_ADDR),bus=i2c,id=yadro-i2c`, где название устройства записано в самом коде. 

Связь с QMP настроена через UNIX-сокет флагом `-qmp unix:/tmp/qmp.sock,server,nowait`. Для начала взаимодействия клиент должен отправить сообщение `{"execute": "qmp_capabilities"}`, на что сервер отвечает `{"return": {}}`.

### Python-скрипт с QMP

Исходный код скрипта находится в [qmp_monitor.py](qmp_monitor.py):
```python
import json
import socket
import time

SOCKET_PATH = "/tmp/qmp.sock"

def send_command(sock, cmd):
    sock.sendall(json.dumps(cmd).encode() + b'\n')
    response = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
        if b'\n' in chunk:
            break
    return json.loads(response)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(SOCKET_PATH)
send_command(sock, {"execute": "qmp_capabilities"})

while True:
    command = {
        "execute": "qom-get",
        "arguments": {
            "path": "/machine/peripheral/yadro-i2c",
            "property": "reg"
        }
    }
    response = send_command(sock, command)
    print(f"Register value: {response.get('return')}")
    time.sleep(1)
```

## Теоретический тест

Ответы на тест находятся в [теоретический_тест.md](docs/теоретический_тест.md)
