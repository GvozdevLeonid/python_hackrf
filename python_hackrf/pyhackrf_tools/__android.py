from python_hackrf import pyhackrf
from threading import Event

try:
    from jnius import autoclass
except ImportError:
    def autoclass(item):
        raise RuntimeError("autoclass not available")

try:
    from android.broadcast import BroadcastReceiver
except ImportError:
    def BroadcastReceiver(item):
        raise RuntimeError("BroadcastReceiver not available")


class USBBroadcastReceiver:
    def start(self):
        self.br = BroadcastReceiver(self.on_broadcast, actions=['libusb.android.USB_PERMISSION'])
        self.br.start()

    def stop(self):
        self.br.stop()

    def on_broadcast(self, context, intent):
        global event

        if intent.getAction() == 'libusb.android.USB_PERMISSION':
            event.set()


event = Event()


def get_usb_device_descriptor():
    global event
    event.clear()

    usb_broadcast_receiver = USBBroadcastReceiver()

    Context = autoclass('android.content.Context')
    PendingIntent = autoclass('android.app.PendingIntent')

    activity = autoclass('org.kivy.android.PythonActivity').mActivity
    usb_manager = activity.getSystemService(Context.USB_SERVICE)
    permission_intent = "libusb.android.USB_PERMISSION"

    flags = PendingIntent.FLAG_IMMUTABLE
    mPermissionIntent = PendingIntent.getBroadcast(activity, 0, autoclass('android.content.Intent')(permission_intent), flags)

    device_list = usb_manager.getDeviceList()
    if device_list:
        usb_device = next(iter(device_list.values()))

        usb_manager.requestPermission(usb_device, mPermissionIntent)

        if not usb_manager.hasPermission(usb_device):
            usb_broadcast_receiver.start()
            event.wait()
            usb_broadcast_receiver.stop()

        if usb_manager.hasPermission(usb_device):
            usb_device_connection = usb_manager.openDevice(usb_device)
            return usb_device_connection.getFileDescriptor()

    return None


def get_device():
    device = None

    file_descriptor = get_usb_device_descriptor()

    if file_descriptor is not None:
        device = pyhackrf.pyhackrf_android_init(file_descriptor)

    return device
