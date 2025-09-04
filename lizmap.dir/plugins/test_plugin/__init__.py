def classFactory(iface):
    """Load TestPlugin class for QGIS Desktop (optional)"""
    from .test_plugin import TestPlugin
    return TestPlugin(iface)

def serverClassFactory(serverIface):
    """Load TestPlugin class for QGIS Server (required)"""
    from .test_plugin import TestPlugin
    return TestPlugin(serverIface)

