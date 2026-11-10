/*
 * Doodle Rescue 3D — Little Joy Arcade bridge.
 *
 * Load this BEFORE arcade-client.js. It exposes a small, stable
 * `window.DoodleRescue` for the Godot build and teaches the arcade client where
 * the game's save lives, because Godot stores it in IndexedDB rather than
 * localStorage.
 *
 * Every call is defensive: outside the arcade, or if the client failed to load,
 * the game keeps saving locally and nothing throws.
 */
(function () {
  'use strict'

  var GAME_ID = 'doodle-rescue-3d'
  var SAVE_KEY = GAME_ID + '-save-v1'

  var lastPushed = null
  var restored = null

  function decodeBase64(value) {
    try {
      return decodeURIComponent(escape(window.atob(String(value))))
    } catch (error) {
      return ''
    }
  }

  function arcade() {
    return window.LittleJoyArcade || null
  }

  window.LJA_SNAPSHOT = function () {
    var snapshot = {}
    if (window.__doodleSave) snapshot[SAVE_KEY] = window.__doodleSave
    return Object.keys(snapshot).length ? snapshot : null
  }

  window.LJA_APPLY_SNAPSHOT = function (keys) {
    if (!keys || typeof keys !== 'object') return
    if (typeof keys[SAVE_KEY] === 'string' && keys[SAVE_KEY].length > 2) {
      restored = keys[SAVE_KEY]
      window.__doodlePendingCloud = restored
    }
  }

  function displayName(user) {
    if (!user) return 'Guest'
    if (user.email) return String(user.email).split('@')[0]
    var meta = user.user_metadata || {}
    return meta.display_name || meta.name || 'Guest'
  }

  window.DoodleRescue = {
    version: 1,

    pushSave: function (base64) {
      var payload = decodeBase64(base64)
      if (!payload) return
      window.__doodleSave = payload
      lastPushed = payload
      var client = arcade()
      if (client && typeof client.push === 'function') {
        // The game saves after every level; the network can wait.
        window.clearTimeout(window.__doodlePushTimer)
        window.__doodlePushTimer = window.setTimeout(function () {
          client.push().catch(function () {})
        }, 2500)
      }
    },

    pullSave: function () {
      var value = restored || window.__doodlePendingCloud || null
      restored = null
      window.__doodlePendingCloud = null
      return value
    },

    identity: function () {
      var client = arcade()
      var user = client && typeof client.user === 'function' ? client.user() : null
      var state = client && typeof client.status === 'function' ? client.status() : null
      var signedIn = !!(state && state.signedIn)
      return {
        signedIn: signedIn,
        name: displayName(user),
        email: user && user.email ? user.email : '',
        status: !client ? 'local' : signedIn ? 'synced' : 'local',
        gameId: GAME_ID,
        saveKey: SAVE_KEY,
        lastPush: lastPushed ? lastPushed.length : 0
      }
    },

    status: function () {
      var client = arcade()
      if (!client) return 'local'
      var state = client && typeof client.status === 'function' ? client.status() : null
      if (!state || !state.signedIn) return 'local'
      return /cloud|saved/i.test(String(state.text || '')) ? 'synced' : 'syncing'
    },

    unlockAchievement: function (id) {
      var slug = String(id)
      window.__doodleLastAchievement = slug
      if (window.console && window.console.debug) {
        window.console.debug('[doodle] achievement', slug)
      }
    },

    track: function (base64) {
      var payload = decodeBase64(base64)
      if (!payload) return
      try {
        var event = JSON.parse(payload)
        if (window.console && window.console.debug) {
          window.console.debug('[doodle]', event.name, event.props || {})
        }
      } catch (error) {
        /* analytics must never break a level */
      }
    },

    signIn: function () {
      if (location.hash !== '#login') {
        location.hash = '#login'
        location.reload()
      }
    },

    openArcade: function () {
      window.open('https://littlejoyarcade.site/#/games', '_blank', 'noopener')
    },

    /* No ad provider ships in this build, so rewarded ads are honestly
       unavailable rather than a fake button. Remove-ads is moot: the game has
       no ads to remove. */
    adsAllowed: function () {
      return false
    }
  }

  window.__doodleSave = window.__doodleSave || null
})()
