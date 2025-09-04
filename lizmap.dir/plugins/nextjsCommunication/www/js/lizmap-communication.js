/**
 * Lizmap NextJS Cross-Origin Communication Plugin
 * Enhanced version with plugin configuration support
 *
 * @version 1.0.0
 * @author Your Name
 * @license MIT
 */

;(function (window) {
  'use strict'

  // Get configuration from plugin
  const config = window.NEXTJS_COMM_CONFIG || {
    allowedOrigins: [window.location.origin],
    debug: false,
    timeout: 10000,
    version: '1.0.0',
  }

  // Enhanced logging
  const logger = {
    debug: (...args) =>
      config.debug && console.log('[Lizmap Communication]', ...args),
    info: (...args) => console.info('[Lizmap Communication]', ...args),
    warn: (...args) => console.warn('[Lizmap Communication]', ...args),
    error: (...args) => console.error('[Lizmap Communication]', ...args),
  }

  // State management
  let lizmapApp = null
  let isReady = false
  let layerCache = new Map()
  let eventListeners = new Map()
  let initializationPromise = null

  // Message queue for messages received before ready
  let messageQueue = []
  let isProcessingQueue = false

  /**
   * Validate message origin against configured allowed origins
   */
  function isValidOrigin(origin) {
    if (!config.allowedOrigins || config.allowedOrigins.length === 0) {
      logger.warn('No allowed origins configured, allowing all')
      return true
    }

    return config.allowedOrigins.some((allowedOrigin) => {
      if (allowedOrigin === '*') return true

      try {
        const allowedUrl = new URL(allowedOrigin)
        const messageUrl = new URL(origin)

        // Allow exact hostname match or subdomain match
        return (
          allowedUrl.hostname === messageUrl.hostname ||
          messageUrl.hostname.endsWith('.' + allowedUrl.hostname)
        )
      } catch (err) {
        logger.warn('Invalid URL in origin validation:', allowedOrigin, origin)
        return allowedOrigin === origin
      }
    })
  }

  /**
   * Send message to parent with error handling and logging
   */
  function sendToParent(message, targetOrigin = '*') {
    try {
      if (!window.parent || window.parent === window) {
        logger.warn('No parent window available')
        return false
      }

      logger.debug('Sending message to parent:', message.type, message)
      window.parent.postMessage(message, targetOrigin)
      return true
    } catch (err) {
      logger.error('Failed to send message to parent:', err)
      return false
    }
  }

  /**
   * Enhanced Lizmap application detection
   */
  function getLizmapApp() {
    if (lizmapApp) return lizmapApp

    // Try multiple detection methods
    const detectionMethods = [
      () => window.lizMap,
      () => window.lizmap,
      () => window.application?.lizmap,
      () => window.lizMap3,
      () => document.lizMap,
      () => {
        // Try to find in global scope
        for (let key in window) {
          if (
            key.toLowerCase().includes('lizmap') &&
            window[key] &&
            typeof window[key] === 'object' &&
            window[key].map
          ) {
            return window[key]
          }
        }
        return null
      },
    ]

    for (const method of detectionMethods) {
      try {
        const app = method()
        if (app && (app.map || app.mainLizmap)) {
          lizmapApp = app
          logger.debug('Found Lizmap app using method:', method.toString())
          break
        }
      } catch (err) {
        logger.debug('Detection method failed:', err)
      }
    }

    return lizmapApp
  }

  /**
   * Enhanced layer detection supporting multiple Lizmap versions
   */
  function getLayers() {
    const app = getLizmapApp()
    if (!app) {
      logger.warn('Lizmap application not available for layer detection')
      return []
    }

    const layers = []

    try {
      // Method 1: Lizmap 3.4+ configuration-based
      if (app.config?.layers) {
        logger.debug('Using config-based layer detection')
        Object.entries(app.config.layers).forEach(([layerId, layerConfig]) => {
          const olLayer =
            app.map?.getLayersByName?.(layerId)?.[0] ||
            app.map?.getLayersBy?.('name', layerId)?.[0]

          layers.push({
            id: layerId,
            name: layerId,
            title: layerConfig.title || layerConfig.name || layerId,
            visible: olLayer
              ? olLayer.getVisibility()
              : layerConfig.visible !== false,
            type: layerConfig.type || 'layer',
            geometryType: layerConfig.geometryType,
            wmsName: layerConfig.wmsName,
          })
        })
      }

      // Method 2: Lizmap 3.6+ state-based
      else if (app.mainLizmap?.state?.layertree) {
        logger.debug('Using state-based layer detection (3.6+)')
        const extractLayersFromTree = (node) => {
          if (node.type === 'layer' && node.name) {
            layers.push({
              id: node.name,
              name: node.name,
              title: node.title || node.name,
              visible: node.checked || node.visibility || false,
              type: node.layerType || 'layer',
              wmsName: node.wmsName,
            })
          }

          if (node.children) {
            node.children.forEach(extractLayersFromTree)
          }
        }

        if (app.mainLizmap.state.layertree.children) {
          app.mainLizmap.state.layertree.children.forEach(extractLayersFromTree)
        }
      }

      // Method 3: Direct OpenLayers layer access
      else if (app.map?.layers) {
        logger.debug('Using OpenLayers direct layer access')
        app.map.layers.forEach((layer) => {
          if (
            layer.name &&
            !layer.name.startsWith('base') &&
            !layer.name.startsWith('__') &&
            layer.CLASS_NAME !== 'OpenLayers.Layer.Vector.RootContainer'
          ) {
            layers.push({
              id: layer.name,
              name: layer.name,
              title: layer.displayName || layer.title || layer.name,
              visible: layer.getVisibility(),
              type: layer.CLASS_NAME || 'layer',
              opacity: layer.opacity,
            })
          }
        })
      }

      // Method 4: Try lizMap.lizmapLayerTree (older versions)
      else if (app.lizmapLayerTreeInstance?.config) {
        logger.debug('Using layer tree instance')
        const treeConfig = app.lizmapLayerTreeInstance.config
        Object.entries(treeConfig).forEach(([layerId, config]) => {
          if (config.type === 'layer') {
            layers.push({
              id: layerId,
              name: layerId,
              title: config.title || layerId,
              visible: config.visible !== false,
              type: 'layer',
            })
          }
        })
      }
    } catch (err) {
      logger.error('Error during layer detection:', err)
    }

    // Cache the layers
    layerCache.clear()
    layers.forEach((layer) => layerCache.set(layer.id, layer))

    logger.debug(
      `Detected ${layers.length} layers:`,
      layers.map((l) => l.name)
    )
    return layers
  }

  /**
   * Enhanced layer visibility toggle with multiple fallback methods
   */
  function toggleLayerVisibility(layerId, visible) {
    const app = getLizmapApp()
    if (!app) {
      throw new Error('Lizmap application not available')
    }

    logger.debug(`Toggling layer ${layerId} visibility to ${visible}`)

    try {
      let success = false

      // Method 1: Lizmap 3.6+ mainLizmap action system
      if (app.mainLizmap?.action) {
        try {
          app.mainLizmap.action.trigger('layertree.layer.visibility', {
            layerId: layerId,
            visibility: visible,
          })
          success = true
          logger.debug('Used mainLizmap action system')
        } catch (err) {
          logger.debug('mainLizmap action failed:', err)
        }
      }

      // Method 2: Direct OpenLayers layer manipulation
      if (!success && app.map) {
        const layer =
          app.map.getLayersByName(layerId)?.[0] ||
          app.map.getLayersBy('name', layerId)?.[0]

        if (layer) {
          layer.setVisibility(visible)
          success = true
          logger.debug('Used direct OpenLayers manipulation')
        }
      }

      // Method 3: Layer tree instance method
      if (!success && app.lizmapLayerTreeInstance) {
        try {
          if (
            typeof app.lizmapLayerTreeInstance.setLayerVisibility === 'function'
          ) {
            app.lizmapLayerTreeInstance.setLayerVisibility(layerId, visible)
            success = true
            logger.debug('Used layer tree instance')
          }
        } catch (err) {
          logger.debug('Layer tree instance method failed:', err)
        }
      }

      // Method 4: Legacy lizMap methods
      if (!success && app.events) {
        try {
          app.events.triggerEvent('lizmaplayer' + (visible ? 'show' : 'hide'), {
            layerId: layerId,
          })
          success = true
          logger.debug('Used legacy event system')
        } catch (err) {
          logger.debug('Legacy event method failed:', err)
        }
      }

      if (!success) {
        throw new Error(`No method succeeded for layer ${layerId}`)
      }

      // Update cache
      if (layerCache.has(layerId)) {
        const cachedLayer = layerCache.get(layerId)
        layerCache.set(layerId, { ...cachedLayer, visible })
      }

      return true
    } catch (err) {
      logger.error('All toggle methods failed for layer', layerId, ':', err)
      throw err
    }
  }

  /**
   * Process message queue when ready
   */
  function processMessageQueue() {
    if (isProcessingQueue || messageQueue.length === 0) {
      return
    }

    isProcessingQueue = true
    logger.debug(`Processing ${messageQueue.length} queued messages`)

    const queue = messageQueue.slice()
    messageQueue = []

    queue.forEach(({ event, message }) => {
      try {
        handleMessageInternal(event, message)
      } catch (err) {
        logger.error('Error processing queued message:', err)
      }
    })

    isProcessingQueue = false
  }

  /**
   * Internal message handler
   */
  function handleMessageInternal(event, message) {
    const response = {
      messageId: message.messageId,
      type: message.type + '_RESPONSE',
      timestamp: Date.now(),
    }

    try {
      switch (message.type) {
        case 'GET_LAYERS':
          const layers = getLayers()
          response.data = { layers }
          response.success = true
          break

        case 'TOGGLE_LAYER_VISIBILITY':
          if (!message.data?.layerId) {
            throw new Error('Layer ID required')
          }

          const { layerId, visible } = message.data
          toggleLayerVisibility(layerId, visible)

          // Broadcast state change
          sendToParent(
            {
              type: 'LAYER_STATE_CHANGED',
              data: { layerId, visible },
              timestamp: Date.now(),
            },
            event.origin
          )

          response.success = true
          response.data = { layerId, visible }
          break

        case 'GET_MAP_INFO':
          const app = getLizmapApp()
          if (app?.map) {
            response.data = {
              extent: app.map.getExtent()?.toArray?.() || null,
              projection: app.map.getProjection() || null,
              center: app.map.getCenter()?.toArray?.() || null,
              zoom: app.map.getZoom() || null,
              scales: app.map.scales || null,
            }
          }
          response.success = true
          break

        case 'INIT_CONFIG':
          logger.info('Received init config:', message.data)
          response.success = true
          break

        case 'PING':
          response.success = true
          response.data = {
            pong: true,
            version: config.version,
            ready: isReady,
          }
          break

        default:
          throw new Error(`Unknown message type: ${message.type}`)
      }
    } catch (err) {
      logger.error('Error handling message:', err)
      response.success = false
      response.error = err.message
    }

    sendToParent(response, event.origin)
  }

  /**
   * Main message handler
   */
  function handleMessage(event) {
    if (!isValidOrigin(event.origin)) {
      logger.warn('Blocked message from invalid origin:', event.origin)
      return
    }

    const message = event.data

    if (!message || typeof message !== 'object' || !message.type) {
      logger.debug('Ignored invalid message:', message)
      return
    }

    logger.debug('Received message:', message.type, 'from', event.origin)

    // Queue messages if not ready yet
    if (!isReady && message.type !== 'PING') {
      logger.debug('Queueing message until ready:', message.type)
      messageQueue.push({ event, message })
      return
    }

    handleMessageInternal(event, message)
  }

  /**
   * Set up event listeners on Lizmap
   */
  function setupEventListeners() {
    const app = getLizmapApp()
    if (!app || !app.map) return

    try {
      // OpenLayers layer change events
      if (app.map.events) {
        const layerChangeHandler = (evt) => {
          if (evt.property === 'visibility' && evt.layer?.name) {
            sendToParent({
              type: 'LAYER_STATE_CHANGED',
              data: {
                layerId: evt.layer.name,
                visible: evt.layer.getVisibility(),
              },
              timestamp: Date.now(),
            })
          }
        }

        app.map.events.register('changelayer', null, layerChangeHandler)
        eventListeners.set('changelayer', layerChangeHandler)
        logger.debug('Registered OpenLayers change events')
      }

      // Lizmap 3.6+ state change events
      if (app.mainLizmap?.state) {
        // This would need to be implemented based on Lizmap 3.6+ event system
        logger.debug('TODO: Implement Lizmap 3.6+ state change listeners')
      }
    } catch (err) {
      logger.error('Error setting up event listeners:', err)
    }
  }

  /**
   * Initialize the communication system
   */
  function initialize() {
    if (initializationPromise) {
      return initializationPromise
    }

    initializationPromise = new Promise((resolve, reject) => {
      let attempts = 0
      const maxAttempts = 30 // 30 seconds with 1-second intervals

      const tryInit = () => {
        attempts++
        logger.debug(`Initialization attempt ${attempts}/${maxAttempts}`)

        const app = getLizmapApp()

        if (!app) {
          if (attempts >= maxAttempts) {
            const error =
              'Failed to find Lizmap application after maximum attempts'
            logger.error(error)
            reject(new Error(error))
            return
          }

          setTimeout(tryInit, 1000)
          return
        }

        // Wait for map to be ready
        if (app.map && app.map.events) {
          const onMapReady = () => {
            logger.info('Lizmap map ready, initializing communication...')
            completeInitialization(resolve)
          }

          if (app.map.getNumLayers && app.map.getNumLayers() > 0) {
            onMapReady()
          } else {
            app.map.events.register('addlayer', null, onMapReady)
            app.map.events.register('loadend', null, onMapReady)

            // Fallback timeout
            setTimeout(onMapReady, 5000)
          }
        }
        // Lizmap 3.6+ readiness check
        else if (app.mainLizmap?.state?.map) {
          logger.info('Lizmap 3.6+ detected, initializing communication...')
          completeInitialization(resolve)
        }
        // Fallback for unknown versions
        else {
          logger.warn(
            'Unknown Lizmap version, attempting fallback initialization...'
          )
          setTimeout(() => completeInitialization(resolve), 2000)
        }
      }

      tryInit()
    })

    return initializationPromise
  }

  /**
   * Complete the initialization process
   */
  function completeInitialization(resolve) {
    if (isReady) {
      resolve()
      return
    }

    try {
      setupEventListeners()
      isReady = true

      logger.info(`Lizmap communication ready (v${config.version})`)

      // Notify parent
      sendToParent({
        type: 'IFRAME_READY',
        data: {
          timestamp: Date.now(),
          version: config.version,
          config: {
            allowedOrigins: config.allowedOrigins.length,
            debug: config.debug,
          },
        },
      })

      // Process any queued messages
      if (messageQueue.length > 0) {
        setTimeout(processMessageQueue, 100)
      }

      resolve()
    } catch (err) {
      logger.error('Error during initialization completion:', err)
      throw err
    }
  }

  /**
   * Cleanup function
   */
  function cleanup() {
    logger.debug('Cleaning up communication system')

    // Remove event listeners
    const app = getLizmapApp()
    if (app?.map?.events && eventListeners.size > 0) {
      eventListeners.forEach((handler, eventType) => {
        try {
          app.map.events.unregister(eventType, null, handler)
        } catch (err) {
          logger.debug('Error removing event listener:', eventType, err)
        }
      })
    }

    // Clear caches
    layerCache.clear()
    eventListeners.clear()
    messageQueue = []

    isReady = false
    lizmapApp = null
    initializationPromise = null
  }

  // Set up message listener
  window.addEventListener('message', handleMessage, false)

  // Set up cleanup on page unload
  window.addEventListener('beforeunload', cleanup)

  // Start initialization based on document state
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize)
  } else {
    // Slight delay to ensure Lizmap has started loading
    setTimeout(initialize, 100)
  }

  // Backup initialization triggers
  window.addEventListener('load', () => {
    if (!isReady) {
      setTimeout(initialize, 500)
    }
  })

  // Expose debugging interface in development
  if (config.debug) {
    window.lizmapCommDebug = {
      getLayers,
      toggleLayerVisibility,
      isReady: () => isReady,
      getApp: getLizmapApp,
      layerCache,
      config,
      messageQueue: () => [...messageQueue],
      reinitialize: () => {
        cleanup()
        return initialize()
      },
      sendTestMessage: (type, data) => {
        sendToParent({ type, data, messageId: 'debug-' + Date.now() })
      },
    }

    logger.info('Debug interface available at window.lizmapCommDebug')
  }

  // Version information
  logger.info(`Lizmap NextJS Communication Plugin v${config.version} loaded`)
})(window)
