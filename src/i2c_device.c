/* Simple I2C device with a single 8-bit register. */

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
