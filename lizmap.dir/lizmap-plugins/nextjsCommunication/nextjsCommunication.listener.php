<?php
/**
 * NextJS Communication Plugin Event Listener
 *
 * This listener handles Lizmap events to inject the communication script
 * and configure cross-origin communication settings.
 *
 * @author Your Name
 * @copyright 2024
 * @link https://github.com/your-repo/lizmap-nextjs-communication
 * @license MIT
 */

class nextjsCommunicationListener extends jEventListener
{
    /**
     * Handle the lizmap project loading event
     * This is triggered when a Lizmap project is being displayed
     */
    function ongetMapAdditions($event)
    {
        $config = $this->getPluginConfig();

        if (!$config || !$config->enabled) {
            return;
        }

        $project = $event->project;
        $repository = $event->repository;

        // Get the project configuration
        $projectConfig = $project->getQgisProjectParameters();

        // Check if this project should have communication enabled
        if ($this->shouldEnableCommunication($project, $config)) {
            $this->injectCommunicationScript($event, $config);
        }
    }

    /**
     * Handle the map view event to add custom headers if needed
     */
    function onmapDockable($event)
    {
        $config = $this->getPluginConfig();

        if (!$config || !$config->enabled) {
            return;
        }

        // Add any custom dock content if needed
        $this->addCustomMapControls($event, $config);
    }

    /**
     * Handle lizmap configuration to add CORS headers
     */
    function onLizmapMapGetResponse($event)
    {
        $config = $this->getPluginConfig();

        if (!$config || !$config->enabled) {
            return;
        }

        $response = $event->getParam('response');

        // Add CORS headers if configured
        if (isset($config->cors) && $config->cors->enabled) {
            $this->addCorsHeaders($response, $config->cors);
        }
    }

    /**
     * Get plugin configuration
     */
    private function getPluginConfig()
    {
        $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');

        if (!file_exists($configFile)) {
            // Create default config if it doesn't exist
            $this->createDefaultConfig($configFile);
        }

        return parse_ini_file($configFile, true);
    }

    /**
     * Check if communication should be enabled for this project
     */
    private function shouldEnableCommunication($project, $config)
    {
        // Always enable if global setting is true
        if (isset($config['global']['always_enable']) && $config['global']['always_enable']) {
            return true;
        }

        // Check project-specific settings
        $projectKey = $project->getRepository()->getKey() . '~' . $project->getKey();

        if (isset($config['projects'][$projectKey])) {
            return $config['projects'][$projectKey];
        }

        // Check for project metadata flag
        $qgisProjectXml = $project->getQgisProjectXml();
        if ($qgisProjectXml) {
            $xpath = new DOMXPath($qgisProjectXml);
            $enabledNodes = $xpath->query("//customproperties/property[@key='nextjs_communication_enabled']/@value");

            if ($enabledNodes->length > 0) {
                return $enabledNodes->item(0)->nodeValue === 'true';
            }
        }

        // Default to enabled if no specific configuration
        return isset($config['global']['default_enabled']) ? $config['global']['default_enabled'] : true;
    }

    /**
     * Inject the communication script into the map view
     */
    private function injectCommunicationScript($event, $config)
    {
        $js = array();

        // Get allowed origins from config
        $allowedOrigins = $this->getAllowedOrigins($config);

        // Add configuration variables
        $js[] = "window.NEXTJS_COMM_CONFIG = " . json_encode(array(
            'allowedOrigins' => $allowedOrigins,
            'debug' => isset($config['debug']['enabled']) ? $config['debug']['enabled'] : false,
            'timeout' => isset($config['global']['timeout']) ? (int)$config['global']['timeout'] : 10000,
            'version' => '1.0.0'
        )) . ";";

        // Add the main communication script
        $scriptPath = jApp::config()->urlengine['basePath'] . 'plugins/nextjsCommunication/www/js/lizmap-communication.js';
        $js[] = sprintf(
            'var script = document.createElement("script");
             script.src = "%s";
             script.async = true;
             document.head.appendChild(script);',
            $scriptPath
        );

        // Add inline script for immediate initialization
        $event->add(array(
            'js' => $js,
            'jscode' => implode("\n", $js)
        ));
    }

    /**
     * Get allowed origins from configuration
     */
    private function getAllowedOrigins($config)
    {
        $origins = array();

        // Always allow same origin
        $origins[] = $this->getCurrentOrigin();

        // Add configured origins
        if (isset($config['cors']['allowed_origins'])) {
            $configuredOrigins = is_array($config['cors']['allowed_origins'])
                ? $config['cors']['allowed_origins']
                : explode(',', $config['cors']['allowed_origins']);

            foreach ($configuredOrigins as $origin) {
                $origin = trim($origin);
                if (!empty($origin) && !in_array($origin, $origins)) {
                    $origins[] = $origin;
                }
            }
        }

        // Add development origins if debug is enabled
        if (isset($config['debug']['enabled']) && $config['debug']['enabled']) {
            $devOrigins = array('http://localhost:3000', 'http://localhost:3001', 'http://127.0.0.1:3000');
            foreach ($devOrigins as $origin) {
                if (!in_array($origin, $origins)) {
                    $origins[] = $origin;
                }
            }
        }

        return $origins;
    }

    /**
     * Get current origin
     */
    private function getCurrentOrigin()
    {
        $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'];
        return $protocol . '://' . $host;
    }

    /**
     * Add CORS headers to response
     */
    private function addCorsHeaders($response, $corsConfig)
    {
        if (isset($corsConfig['allowed_origins'])) {
            $origins = is_array($corsConfig['allowed_origins'])
                ? implode(', ', $corsConfig['allowed_origins'])
                : $corsConfig['allowed_origins'];

            $response->addHttpHeader('Access-Control-Allow-Origin', $origins);
        }

        if (isset($corsConfig['allowed_methods'])) {
            $response->addHttpHeader('Access-Control-Allow-Methods', $corsConfig['allowed_methods']);
        } else {
            $response->addHttpHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        }

        if (isset($corsConfig['allowed_headers'])) {
            $response->addHttpHeader('Access-Control-Allow-Headers', $corsConfig['allowed_headers']);
        } else {
            $response->addHttpHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        }

        if (isset($corsConfig['max_age'])) {
            $response->addHttpHeader('Access-Control-Max-Age', $corsConfig['max_age']);
        }

        if (isset($corsConfig['allow_credentials']) && $corsConfig['allow_credentials']) {
            $response->addHttpHeader('Access-Control-Allow-Credentials', 'true');
        }
    }

    /**
     * Add custom map controls if needed
     */
    private function addCustomMapControls($event, $config)
    {
        // This can be used to add custom UI elements to the map
        // if needed for the communication functionality

        if (isset($config['ui']['show_communication_status']) && $config['ui']['show_communication_status']) {
            $event->add(array(
                'dock' => array(
                    'nextjs-communication-status' => array(
                        'title' => 'Communication Status',
                        'content' => '<div id="nextjs-comm-status">Initializing...</div>'
                    )
                )
            ));
        }
    }

    /**
     * Create default configuration file
     */
    private function createDefaultConfig($configFile)
    {
        $defaultConfig = <<<CONFIG
;<?php die(''); ?>
;for security reasons, don't remove or modify the first line

[global]
; Enable the plugin globally
enabled=1

; Enable communication by default for all projects
default_enabled=1

; Always enable communication (overrides project-specific settings)
always_enable=0

; Timeout for initialization (milliseconds)
timeout=10000

[cors]
; Enable CORS headers
enabled=1

; Allowed origins (comma-separated)
allowed_origins="https://your-nextjs-domain.com"

; Allowed HTTP methods
allowed_methods="GET, POST, OPTIONS"

; Allowed headers
allowed_headers="Content-Type, Authorization"

; Max age for preflight requests (seconds)
max_age=3600

; Allow credentials
allow_credentials=0

[debug]
; Enable debug mode (adds localhost origins and debug logging)
enabled=0

; Log communication messages
log_messages=0

[ui]
; Show communication status in map dock
show_communication_status=0

; Custom CSS for communication UI
custom_css=""

[projects]
; Project-specific settings
; Format: repository~project=1 (enabled) or 0 (disabled)
; Example: myrepo~myproject=1

CONFIG;

        file_put_contents($configFile, $defaultConfig);

        // Log the creation
        jLog::log('Created default configuration for nextjsCommunication plugin', 'notice');
    }
}
?>
