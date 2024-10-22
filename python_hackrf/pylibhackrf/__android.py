from threading import Event

try:
    from jnius import autoclass
except ImportError:
    def autoclass(item):
        raise RuntimeError('autoclass not available')

try:
    from android.broadcast import BroadcastReceiver
except ImportError:
    def BroadcastReceiver(item):
        raise RuntimeError('BroadcastReceiver not available')

hackrf_usb_vid = 0x1d50
hackrf_usb_pids = (0x604b, 0x6089, 0xcc15)


class USBBroadcastReceiver:
    def __init__(self, events):
        self.events = events

    def start(self):
        self.br = BroadcastReceiver(self.on_broadcast, actions=['libusb.android.USB_PERMISSION'])
        self.br.start()

    def stop(self):
        self.br.stop()

    def on_broadcast(self, context, intent):
        action = intent.getAction()
        if action == 'libusb.android.USB_PERMISSION':
            Context = autoclass('android.content.Context')
            activity = autoclass('org.kivy.android.PythonActivity').mActivity
            usb_manager = activity.getSystemService(Context.USB_SERVICE)
            usb_device = intent.getParcelableExtra(usb_manager.EXTRA_DEVICE)
            granted = intent.getBooleanExtra(usb_manager.EXTRA_PERMISSION_GRANTED, False)
            device_name = usb_device.getDeviceName()
            print(device_name, granted)
            if device_name in self.events:
                self.events[device_name]['granted'] = granted
                self.events[device_name]['device'] = usb_device
                self.events[device_name]['event'].set()


def get_usb_devices_info(num_devices: int = None) -> list:
    events = {}
    device_file_descriptors = []

    usb_broadcast_receiver = USBBroadcastReceiver(events)

    Context = autoclass('android.content.Context')
    PendingIntent = autoclass('android.app.PendingIntent')

    activity = autoclass('org.kivy.android.PythonActivity').mActivity
    usb_manager = activity.getSystemService(Context.USB_SERVICE)
    permission_intent = 'libusb.android.USB_PERMISSION'

    flags = PendingIntent.FLAG_IMMUTABLE
    mPermissionIntent = PendingIntent.getBroadcast(activity, 0, autoclass('android.content.Intent')(permission_intent), flags)

    device_list = usb_manager.getDeviceList()
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
                    device_file_descriptors.append((file_descriptor, usb_device.getProductId(), usb_device.getSerialNumber()))
                else:
                    events[device_name] = {'event': Event(), 'granted': False, 'device': None}
                    usb_manager.requestPermission(usb_device, mPermissionIntent)

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
                    device_file_descriptors.append((file_descriptor, usb_device.getProductId(), usb_device.getSerialNumber()))

    return device_file_descriptors
