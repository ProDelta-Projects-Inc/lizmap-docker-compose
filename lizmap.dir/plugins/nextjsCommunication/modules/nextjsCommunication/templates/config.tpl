<!-- templates/config.tpl -->
<div class="nextjs-communication-admin">
    <h2>{@nextjsCommunication~admin.page.title@}</h2>

    <!-- Status Panel -->
    <div class="alert alert-info">
        <h4>{@nextjsCommunication~admin.status.title@}</h4>
        <div id="plugin-status">
            <p><i class="fa fa-spin fa-spinner"></i> {@nextjsCommunication~admin.status.loading@}</p>
        </div>
    </div>

    <form action="{jurl 'nextjsCommunication~admin:save'}" method="post" class="form-horizontal" id="config-form">

        <!-- Global Settings -->
        <fieldset>
            <legend>{@nextjsCommunication~admin.global.title@}</legend>

            <div class="control-group">
                <label class="control-label" for="global_enabled">{@nextjsCommunication~admin.global.enabled@}</label>
                <div class="controls">
                    <input type="checkbox" id="global_enabled" name="global_enabled" value="1"
                           {if isset($config.global.enabled) && $config.global.enabled}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.global.enabled.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="default_enabled">{@nextjsCommunication~admin.global.default_enabled@}</label>
                <div class="controls">
                    <input type="checkbox" id="default_enabled" name="default_enabled" value="1"
                           {if !isset($config.global.default_enabled) || $config.global.default_enabled}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.global.default_enabled.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="always_enable">{@nextjsCommunication~admin.global.always_enable@}</label>
                <div class="controls">
                    <input type="checkbox" id="always_enable" name="always_enable" value="1"
                           {if isset($config.global.always_enable) && $config.global.always_enable}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.global.always_enable.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="timeout">{@nextjsCommunication~admin.global.timeout@}</label>
                <div class="controls">
                    <div class="input-append">
                        <input type="number" id="timeout" name="timeout" class="input-small"
                               value="{if isset($config.global.timeout)}{$config.global.timeout}{else}10000{/if}"
                               min="1000" max="60000" step="1000">
                        <span class="add-on">ms</span>
                    </div>
                    <span class="help-inline">{@nextjsCommunication~admin.global.timeout.help@}</span>
                </div>
            </div>
        </fieldset>

        <!-- CORS Settings -->
        <fieldset>
            <legend>{@nextjsCommunication~admin.cors.title@}</legend>

            <div class="control-group">
                <label class="control-label" for="cors_enabled">{@nextjsCommunication~admin.cors.enabled@}</label>
                <div class="controls">
                    <input type="checkbox" id="cors_enabled" name="cors_enabled" value="1"
                           {if isset($config.cors.enabled) && $config.cors.enabled}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.cors.enabled.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="allowed_origins">{@nextjsCommunication~admin.cors.allowed_origins@}</label>
                <div class="controls">
                    <textarea id="allowed_origins" name="allowed_origins" class="input-xxlarge" rows="3"
                              placeholder="https://your-nextjs-domain.com, https://app.example.com">{if isset($config.cors.allowed_origins)}{$config.cors.allowed_origins}{/if}</textarea>
                    <span class="help-block">{@nextjsCommunication~admin.cors.allowed_origins.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="allowed_methods">{@nextjsCommunication~admin.cors.allowed_methods@}</label>
                <div class="controls">
                    <input type="text" id="allowed_methods" name="allowed_methods" class="input-large"
                           value="{if isset($config.cors.allowed_methods)}{$config.cors.allowed_methods}{else}GET, POST, OPTIONS{/if}">
                    <span class="help-inline">{@nextjsCommunication~admin.cors.allowed_methods.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="allowed_headers">{@nextjsCommunication~admin.cors.allowed_headers@}</label>
                <div class="controls">
                    <input type="text" id="allowed_headers" name="allowed_headers" class="input-xlarge"
                           value="{if isset($config.cors.allowed_headers)}{$config.cors.allowed_headers}{else}Content-Type, Authorization{/if}">
                    <span class="help-inline">{@nextjsCommunication~admin.cors.allowed_headers.help@}</span>
                </div>
            </div>
        </fieldset>

        <!-- Debug Settings -->
        <fieldset>
            <legend>{@nextjsCommunication~admin.debug.title@}</legend>

            <div class="control-group">
                <label class="control-label" for="debug_enabled">{@nextjsCommunication~admin.debug.enabled@}</label>
                <div class="controls">
                    <input type="checkbox" id="debug_enabled" name="debug_enabled" value="1"
                           {if isset($config.debug.enabled) && $config.debug.enabled}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.debug.enabled.help@}</span>
                </div>
            </div>

            <div class="control-group">
                <label class="control-label" for="log_messages">{@nextjsCommunication~admin.debug.log_messages@}</label>
                <div class="controls">
                    <input type="checkbox" id="log_messages" name="log_messages" value="1"
                           {if isset($config.debug.log_messages) && $config.debug.log_messages}checked="checked"{/if}>
                    <span class="help-inline">{@nextjsCommunication~admin.debug.log_messages.help@}</span>
                </div>
            </div>
        </fieldset>

        <!-- Project-Specific Settings -->
        {if count($projects) > 0}
        <fieldset>
            <legend>{@nextjsCommunication~admin.projects.title@}</legend>
            <p class="help-block">{@nextjsCommunication~admin.projects.help@}</p>

            {foreach $projects as $repoKey => $repo}
            <div class="project-repository">
                <h4>{$repo.label|default:$repo.name}</h4>
                {if count($repo.projects) > 0}
                    {foreach $repo.projects as $projectKey => $project}
                    <div class="control-group">
                        <label class="control-label" for="project_{$projectKey}">
                            {$project.title|default:$project.key}
                        </label>
                        <div class="controls">
                            <select id="project_{$projectKey}" name="project_settings[{$projectKey}]" class="input-medium">
                                <option value="">{@nextjsCommunication~admin.projects.inherit@}</option>
                                <option value="1" {if isset($config.projects[$projectKey]) && $config.projects[$projectKey] == '1'}selected="selected"{/if}>
                                    {@nextjsCommunication~admin.projects.enabled@}
                                </option>
                                <option value="0" {if isset($config.projects[$projectKey]) && $config.projects[$projectKey] == '0'}selected="selected"{/if}>
                                    {@nextjsCommunication~admin.projects.disabled@}
                                </option>
                            </select>
                            {if $project.abstract}
                            <span class="help-inline">{$project.abstract|truncate:100}</span>
                            {/if}
                        </div>
                    </div>
                    {/foreach}
                {else}
                    <p class="muted">{@nextjsCommunication~admin.projects.none@}</p>
                {/if}
            </div>
            {/foreach}
        </fieldset>
        {/if}

        <!-- Connection Test -->
        <fieldset>
            <legend>{@nextjsCommunication~admin.test.title@}</legend>

            <div class="control-group">
                <label class="control-label" for="test_url">{@nextjsCommunication~admin.test.url@}</label>
                <div class="controls">
                    <div class="input-append">
                        <input type="url" id="test_url" name="test_url" class="input-xlarge"
                               placeholder="https://your-nextjs-app.com">
                        <button type="button" class="btn" id="test-connection">
                            <i class="fa fa-plug"></i> {@nextjsCommunication~admin.test.button@}
                        </button>
                    </div>
                    <div id="test-result" style="margin-top: 10px;"></div>
                </div>
            </div>
        </fieldset>

        <!-- Actions -->
        <div class="form-actions">
            <button type="submit" class="btn btn-primary">
                <i class="fa fa-save"></i> {@nextjsCommunication~admin.save@}
            </button>

            <div class="btn-group" style="margin-left: 10px;">
                <a href="{jurl 'nextjsCommunication~admin:export'}" class="btn">
                    <i class="fa fa-download"></i> {@nextjsCommunication~admin.export@}
                </a>
                <button type="button" class="btn" id="import-config">
                    <i class="fa fa-upload"></i> {@nextjsCommunication~admin.import@}
                </button>
            </div>

            <button type="button" class="btn btn-info" id="reload-status" style="margin-left: 10px;">
                <i class="fa fa-refresh"></i> {@nextjsCommunication~admin.reload_status@}
            </button>
        </div>
    </form>

    <!-- Hidden file input for import -->
    <form id="import-form" style="display: none;" action="{jurl 'nextjsCommunication~admin:import'}" method="post" enctype="multipart/form-data">
        <input type="file" id="config-file-input" name="config_file" accept=".ini,.txt">
    </form>
</div>

<script>
$(document).ready(function() {
    // Load status information
    function loadStatus() {
        $('#plugin-status').html('<p><i class="fa fa-spin fa-spinner"></i> Loading...</p>');

        $.getJSON('{jurl "nextjsCommunication~admin:status"}')
            .done(function(data) {
                var html = '<table class="table table-condensed">';
                html += '<tr><td>Plugin Installed:</td><td>' + (data.plugin_installed ? '<span class="label label-success">Yes</span>' : '<span class="label label-important">No</span>') + '</td></tr>';
                html += '<tr><td>Configuration File:</td><td>' + (data.config_exists ? '<span class="label label-success">Found</span>' : '<span class="label label-warning">Not Found</span>') + '</td></tr>';
                html += '<tr><td>JavaScript File:</td><td>' + (data.js_file_exists ? '<span class="label label-success">Found</span>' : '<span class="label label-important">Missing</span>') + '</td></tr>';
                html += '<tr><td>Configuration Writable:</td><td>' + (data.config_writable ? '<span class="label label-success">Yes</span>' : '<span class="label label-important">No</span>') + '</td></tr>';
                html += '<tr><td>Plugin Version:</td><td>' + data.plugin_version + '</td></tr>';
                html += '<tr><td>Lizmap Version:</td><td>' + data.lizmap_version + '</td></tr>';

                if (data.config) {
                    html += '<tr><td>Plugin Enabled:</td><td>' + (data.config.enabled ? '<span class="label label-success">Yes</span>' : '<span class="label">No</span>') + '</td></tr>';
                    html += '<tr><td>CORS Enabled:</td><td>' + (data.config.cors_enabled ? '<span class="label label-success">Yes</span>' : '<span class="label">No</span>') + '</td></tr>';
                    html += '<tr><td>Debug Mode:</td><td>' + (data.config.debug_enabled ? '<span class="label label-warning">Yes</span>' : '<span class="label">No</span>') + '</td></tr>';
                    html += '<tr><td>Allowed Origins:</td><td>' + data.config.allowed_origins_count + '</td></tr>';
                }

                html += '</table>';
                $('#plugin-status').html(html);
            })
            .fail(function() {
                $('#plugin-status').html('<p class="text-error"><i class="fa fa-exclamation-triangle"></i> Failed to load status information</p>');
            });
    }

    // Test connection functionality
    $('#test-connection').click(function() {
        var url = $('#test_url').val();
        if (!url) {
            $('#test-result').html('<div class="alert alert-error">Please enter a URL to test</div>');
            return;
        }

        var $btn = $(this);
        var originalText = $btn.html();
        $btn.html('<i class="fa fa-spin fa-spinner"></i> Testing...').prop('disabled', true);

        $.post('{jurl "nextjsCommunication~admin:test"}', { test_url: url })
            .done(function(data) {
                if (data.success) {
                    $('#test-result').html('<div class="alert alert-success"><strong>Success!</strong> ' + data.message + '</div>');
                } else {
                    $('#test-result').html('<div class="alert alert-error"><strong>Failed:</strong> ' + data.error + '</div>');
                }
            })
            .fail(function() {
                $('#test-result').html('<div class="alert alert-error"><strong>Error:</strong> Failed to perform connection test</div>');
            })
            .always(function() {
                $btn.html(originalText).prop('disabled', false);
            });
    });

    // Import configuration functionality
    $('#import-config').click(function() {
        $('#config-file-input').click();
    });

    $('#config-file-input').change(function() {
        if (this.files.length > 0) {
            if (confirm('This will replace your current configuration. Are you sure?')) {
                $('#import-form').submit();
            }
        }
    });

    // Reload status
    $('#reload-status').click(function() {
        loadStatus();
    });

    // Form validation
    $('#config-form').submit(function(e) {
        var allowedOrigins = $('#allowed_origins').val().trim();
        if ($('#cors_enabled').is(':checked') && !allowedOrigins) {
            alert('Please specify allowed origins when CORS is enabled.');
            e.preventDefault();
            return false;
        }

        // Validate origin URLs
        if (allowedOrigins) {
            var origins = allowedOrigins.split(',');
            for (var i = 0; i < origins.length; i++) {
                var origin = origins[i].trim();
                if (origin && !origin.match(/^https?:\/\/.+/)) {
                    alert('Invalid origin format: ' + origin + '\nOrigins should start with http:// or https://');
                    e.preventDefault();
                    return false;
                }
            }
        }

        return true;
    });

    // Enable/disable dependent fields
    $('#cors_enabled').change(function() {
        var corsFields = $('#allowed_origins, #allowed_methods, #allowed_headers');
        if ($(this).is(':checked')) {
            corsFields.prop('disabled', false).closest('.control-group').removeClass('disabled');
        } else {
            corsFields.prop('disabled', true).closest('.control-group').addClass('disabled');
        }
    }).trigger('change');

    $('#global_enabled').change(function() {
        var allFields = $('#config-form').find('input, select, textarea').not('#global_enabled');
        if ($(this).is(':checked')) {
            allFields.prop('disabled', false).closest('.control-group').removeClass('disabled');
        } else {
            allFields.prop('disabled', true).closest('.control-group').addClass('disabled');
        }
        // Re-trigger CORS field state
        $('#cors_enabled').trigger('change');
    }).trigger('change');

    // Load initial status
    loadStatus();

    // Auto-save draft functionality
    var autoSaveTimer;
    $('#config-form input, #config-form select, #config-form textarea').change(function() {
        clearTimeout(autoSaveTimer);
        autoSaveTimer = setTimeout(function() {
            // Could implement auto-save to localStorage here
            console.log('Configuration changed - consider auto-save');
        }, 2000);
    });
});
</script>

<style>
.nextjs-communication-admin .control-group.disabled {
    opacity: 0.6;
}

.nextjs-communication-admin .project-repository {
    background: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 15px;
    margin-bottom: 15px;
}

.nextjs-communication-admin .project-repository h4 {
    margin-top: 0;
    color: #333;
    border-bottom: 1px solid #ddd;
    padding-bottom: 5px;
}

.nextjs-communication-admin #test-result .alert {
    margin-bottom: 0;
}

.nextjs-communication-admin .form-actions {
    background: none;
    border: none;
    margin: 0;
    padding-top: 20px;
}

.nextjs-communication-admin fieldset {
    margin-bottom: 30px;
}

.nextjs-communication-admin legend {
    color: #333;
    font-weight: bold;
}
</style>
