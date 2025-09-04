<?php
/**
 * NextJS Communication Plugin Admin Controller
 *
 * Provides administrative interface for managing plugin configuration
 */

class adminCtrl extends jController
{
    /**
     * Check if user has admin rights
     */
    private function checkAdminRights()
    {
        if (!jAuth::isConnected()) {
            $this->getResponse('redirect')->action = 'jauth~login:form';
            return false;
        }

        if (!jAcl2::check('lizmap.admin.access')) {
            throw new jException('Access denied');
        }

        return true;
    }

    /**
     * Main configuration page
     */
    function index()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('html');
        $rep->title = jLocale::get('nextjsCommunication~admin.page.title');

        $tpl = new jTpl();

        // Load current configuration
        $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');
        $config = array();

        if (file_exists($configFile)) {
            $config = parse_ini_file($configFile, true);
        }

        $tpl->assign('config', $config);
        $tpl->assign('configFile', $configFile);
        $tpl->assign('configExists', file_exists($configFile));

        // Get project list for per-project configuration
        $projects = $this->getProjectList();
        $tpl->assign('projects', $projects);

        $rep->body->assign('MAIN', $tpl->fetch('config'));

        return $rep;
    }

    /**
     * Save configuration
     */
    function save()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('redirect');
        $rep->action = 'nextjsCommunication~admin:index';

        try {
            $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');

            // Build configuration from form data
            $config = array(
                'global' => array(
                    'enabled' => $this->param('global_enabled', '0'),
                    'default_enabled' => $this->param('default_enabled', '1'),
                    'always_enable' => $this->param('always_enable', '0'),
                    'timeout' => (int)$this->param('timeout', '10000')
                ),
                'cors' => array(
                    'enabled' => $this->param('cors_enabled', '0'),
                    'allowed_origins' => $this->param('allowed_origins', ''),
                    'allowed_methods' => $this->param('allowed_methods', 'GET, POST, OPTIONS'),
                    'allowed_headers' => $this->param('allowed_headers', 'Content-Type, Authorization'),
                    'max_age' => (int)$this->param('max_age', '3600'),
                    'allow_credentials' => $this->param('allow_credentials', '0')
                ),
                'debug' => array(
                    'enabled' => $this->param('debug_enabled', '0'),
                    'log_messages' => $this->param('log_messages', '0')
                ),
                'ui' => array(
                    'show_communication_status' => $this->param('show_status', '0'),
                    'custom_css' => $this->param('custom_css', '')
                ),
                'projects' => array()
            );

            // Handle project-specific settings
            $projectSettings = $this->param('project_settings', array());
            if (is_array($projectSettings)) {
                foreach ($projectSettings as $projectKey => $enabled) {
                    $config['projects'][$projectKey] = $enabled;
                }
            }

            $this->writeConfigFile($configFile, $config);

            jMessage::add(jLocale::get('nextjsCommunication~admin.config.saved'), 'notice');

        } catch (Exception $e) {
            jMessage::add('Error saving configuration: ' . $e->getMessage(), 'error');
        }

        return $rep;
    }

    /**
     * Test communication with a NextJS endpoint
     */
    function test()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('json');

        $testUrl = $this->param('test_url');
        if (!$testUrl) {
            $rep->data = array('success' => false, 'error' => 'No test URL provided');
            return $rep;
        }

        try {
            // Validate URL
            $parsedUrl = parse_url($testUrl);
            if (!$parsedUrl || !isset($parsedUrl['scheme']) || !isset($parsedUrl['host'])) {
                throw new Exception('Invalid URL format');
            }

            // Perform a simple HTTP test
            $context = stream_context_create(array(
                'http' => array(
                    'method' => 'GET',
                    'timeout' => 10,
                    'header' => array(
                        'User-Agent: Lizmap-NextJS-Communication-Test/1.0'
                    )
                )
            ));

            $result = @file_get_contents($testUrl, false, $context);

            if ($result === false) {
                $error = error_get_last();
                throw new Exception($error['message'] ?? 'Connection failed');
            }

            $rep->data = array(
                'success' => true,
                'message' => 'Connection successful',
                'url' => $testUrl,
                'response_length' => strlen($result)
            );

        } catch (Exception $e) {
            $rep->data = array(
                'success' => false,
                'error' => $e->getMessage(),
                'url' => $testUrl
            );
        }

        return $rep;
    }

    /**
     * Get status information
     */
    function status()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('json');

        $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');
        $pluginDir = jApp::config()->pluginsPath . '/nextjsCommunication/';
        $jsFile = $pluginDir . 'www/js/lizmap-communication.js';

        $status = array(
            'plugin_installed' => is_dir($pluginDir),
            'config_exists' => file_exists($configFile),
            'js_file_exists' => file_exists($jsFile),
            'config_writable' => is_writable(dirname($configFile)),
            'plugin_version' => '1.0.0',
            'lizmap_version' => $this->getLizmapVersion()
        );

        if (file_exists($configFile)) {
            $config = parse_ini_file($configFile, true);
            $status['config'] = array(
                'enabled' => isset($config['global']['enabled']) ? $config['global']['enabled'] : false,
                'cors_enabled' => isset($config['cors']['enabled']) ? $config['cors']['enabled'] : false,
                'debug_enabled' => isset($config['debug']['enabled']) ? $config['debug']['enabled'] : false,
                'allowed_origins_count' => isset($config['cors']['allowed_origins']) ?
                    count(explode(',', $config['cors']['allowed_origins'])) : 0
            );
        }

        $rep->data = $status;
        return $rep;
    }

    /**
     * Export configuration
     */
    function export()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('binary');
        $rep->mimeType = 'application/octet-stream';
        $rep->outputFileName = 'nextjs-communication-config.ini';

        $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');

        if (file_exists($configFile)) {
            $rep->fileName = $configFile;
        } else {
            $rep->content = '; No configuration file found';
        }

        return $rep;
    }

    /**
     * Import configuration
     */
    function import()
    {
        if (!$this->checkAdminRights()) return;

        $rep = $this->getResponse('redirect');
        $rep->action = 'nextjsCommunication~admin:index';

        try {
            if (!isset($_FILES['config_file']) || $_FILES['config_file']['error'] !== UPLOAD_ERR_OK) {
                throw new Exception('No file uploaded or upload error');
            }

            $uploadedFile = $_FILES['config_file']['tmp_name'];
            $config = parse_ini_file($uploadedFile, true);

            if ($config === false) {
                throw new Exception('Invalid configuration file format');
            }

            $configFile = jApp::varConfigPath('nextjsCommunication.ini.php');
            $this->writeConfigFile($configFile, $config);

            jMessage::add(jLocale::get('nextjsCommunication~admin.config.imported'), 'notice');

        } catch (Exception $e) {
            jMessage::add('Error importing configuration: ' . $e->getMessage(), 'error');
        }

        return $rep;
    }

    /**
     * Get list of available projects
     */
    private function getProjectList()
    {
        $projects = array();

        try {
            $services = lizmap::getServices();
            $repositories = $services->getRepositoryList();

            foreach ($repositories as $repo) {
                $projects[$repo->getKey()] = array(
                    'name' => $repo->getKey(),
                    'label' => $repo->getData('label'),
                    'projects' => array()
                );

                foreach ($repo->getProjects() as $project) {
                    $projectKey = $repo->getKey() . '~' . $project->getKey();
                    $projects[$repo->getKey()]['projects'][$projectKey] = array(
                        'key' => $project->getKey(),
                        'title' => $project->getData('title'),
                        'abstract' => $project->getData('abstract')
                    );
                }
            }
        } catch (Exception $e) {
            jLog::log('Error loading project list: ' . $e->getMessage(), 'error');
        }

        return $projects;
    }

    /**
     * Write configuration file
     */
    private function writeConfigFile($filename, $config)
    {
        $content = ";<?php die(''); ?>\n;for security reasons, don't remove or modify the first line\n\n";

        foreach ($config as $section => $values) {
            $content .= "[$section]\n";
            foreach ($values as $key => $value) {
                if (is_bool($value)) {
                    $value = $value ? '1' : '0';
                } elseif (is_string($value) && (strpos($value, ' ') !== false || strpos($value, ',') !== false)) {
                    $value = '"' . $value . '"';
                }
                $content .= "$key=$value\n";
            }
            $content .= "\n";
        }

        if (!file_put_contents($filename, $content)) {
            throw new Exception("Cannot write configuration file: $filename");
        }

        // Clear opcache if enabled
        if (function_exists('opcache_invalidate')) {
            opcache_invalidate($filename);
        }
    }

    /**
     * Get Lizmap version
     */
    private function getLizmapVersion()
    {
        try {
            if (class_exists('lizmap')) {
                return lizmap::getVersion();
            }
            return 'Unknown';
        } catch (Exception $e) {
            return 'Unknown';
        }
    }
}
?>
