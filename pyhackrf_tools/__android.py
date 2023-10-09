from python_hackrf import pyhackrf

def get_usb_device_descriptor():
    from jnius import autoclass

    Context = autoclass('android.content.Context')
    PendingIntent = autoclass('android.app.PendingIntent')
    
    activity = autoclass('org.kivy.android.PythonActivity').mActivity
    usb_manager = activity.getSystemService(Context.USB_SERVICE)
    
    device_list = usb_manager.getDeviceList()
    
    permission_intent = "libusb.android.USB_PERMISSION"
    flags = PendingIntent.FLAG_IMMUTABLE
    mPermissionIntent = PendingIntent.getBroadcast(activity, 0, 
        autoclass('android.content.Intent')(permission_intent), flags)
    
    for usb_device in device_list.values():
        usb_manager.requestPermission(usb_device, mPermissionIntent)
    
    usb_device = next(iter(device_list.values()))
    
    usb_device_connection = usb_manager.openDevice(usb_device)
    file_descriptor = usb_device_connection.getFileDescriptor()
    
    return file_descriptor
