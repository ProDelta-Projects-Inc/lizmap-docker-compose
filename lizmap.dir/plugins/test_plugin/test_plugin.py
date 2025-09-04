from qgis.core import QgsMessageLog, Qgis
from qgis.PyQt.QtCore import QObject

class TestPlugin:
    """Minimal test plugin"""

    def __init__(self, iface):
        """Constructor.

        :param iface: An interface instance that will be passed to this class
            which provides the hook by which you can manipulate the QGIS
            application at run time.
        :type iface: QgsInterface
        """
        self.iface = iface
        self.plugin_dir = os.path.dirname(__file__)

    def initGui(self):
        """Create the menu entries and toolbar icons inside the QGIS GUI."""
        QgsMessageLog.logMessage(
            "Test Plugin: initGui() called",
            "TestPlugin",
            Qgis.Info
        )

    def unload(self):
        """Removes the plugin menu item and icon from QGIS GUI."""
        QgsMessageLog.logMessage(
            "Test Plugin: unload() called",
            "TestPlugin",
            Qgis.Info
        )

# ==== Optional: For server-side processing ====
def serverClassFactory(serverIface):
    """Load plugin for QGIS Server"""
    from .test_plugin import TestPlugin
    return TestPlugin(serverIface)
