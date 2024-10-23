from threading import Event

try:
    from jnius import (  # type: ignore
        autoclass,
        cast,
    )
except ImportError:
    def autoclass(item):
        raise RuntimeError('autoclass not available')

    def cast(item):
        raise RuntimeError('cast not available')

try:
    from android.broadcast import BroadcastReceiver  # type: ignore
except ImportError:
    def BroadcastReceiver(item):
        raise RuntimeError('BroadcastReceiver not available')

hackrf_usb_vid = 0x1d50
hackrf_usb_pids = (0x604b, 0x6089, 0xcc15)


class USBBroadcastReceiver:
    def __init__(self, events):
        self.usb_action_permission = 'libusb.android.USB_PERMISSION'
        self.events = events

    def start(self):
        self.br = BroadcastReceiver(self.on_broadcast, actions=[self.usb_action_permission])
        self.br.start()

    def stop(self):
        self.br.stop()

    def on_broadcast(self, context, intent):
        action = intent.getAction()
        UsbManager = autoclass('android.hardware.usb.UsbManager')
        if action == self.usb_action_permission:
            usb_device = cast('android.hardware.usb.UsbDevice', intent.getParcelableExtra(UsbManager.EXTRA_DEVICE))

            if usb_device is not None:
                granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, False)
                device_name = usb_device.getDeviceName()

                if device_name in self.events:
                    self.events[device_name]['granted'] = granted
                    self.events[device_name]['device'] = usb_device
                    self.events[device_name]['event'].set()


def get_usb_devices_info(num_devices: int = None) -> list:
    events = {}
    devices_info = []

    Context = autoclass('android.content.Context')
    PendingIntent = autoclass('android.app.PendingIntent')
    this = autoclass('org.kivy.android.PythonActivity').mActivity

    usb_manager = this.getSystemService(Context.USB_SERVICE)
    device_list = usb_manager.getDeviceList()

    usb_action_permission = 'libusb.android.USB_PERMISSION'
    usb_broadcast_receiver = USBBroadcastReceiver(events)

    if device_list:
        for idx, usb_device in enumerate(device_list.values()):
            device_name = usb_device.getDeviceName()
            if (
                usb_device.getVendorId() == hackrf_usb_vid
                and usb_device.getProductId() in hackrf_usb_pids
            ):

                if usb_manager.hasPermission(usb_device):
                    usb_device_connection = usb_manager.openDevice(usb_device)
                    file_descriptor = usb_device_connection.getFileDescriptor()
                    devices_info.append((file_descriptor, usb_device.getProductId(), usb_device.getSerialNumber()))
                else:
                    permission_intent = PendingIntent.getBroadcast(this.getApplicationContext(), 0, autoclass('android.content.Intent')(usb_action_permission), PendingIntent.FLAG_MUTABLE)
                    events[device_name] = {'event': Event(), 'granted': False, 'device': None}
                    usb_manager.requestPermission(usb_device, permission_intent)

                if num_devices is not None and idx + 1 == num_devices:
                    break

        if len(events):
            usb_broadcast_receiver.start()
            for device_name, info in events.items():
                info['event'].wait()
            usb_broadcast_receiver.stop()

            for device_name, info in events.items():
                if info['granted']:
                    usb_device = info['device']
                    usb_device_connection = usb_manager.openDevice(usb_device)
                    file_descriptor = usb_device_connection.getFileDescriptor()
                    devices_info.append((file_descriptor, usb_device.getProductId(), usb_device.getSerialNumber()))

    return devices_info
