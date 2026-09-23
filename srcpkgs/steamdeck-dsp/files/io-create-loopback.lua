-- io-create-loopback.lua
--
-- Rebuilds what Valve's patched WirePlumber does on SteamOS: for every ALSA
-- node marked with node.create-loopback = true (Valve's alsa-loopback.conf
-- sets that) it creates a libpipewire-module-loopback pair - a stream bound
-- to the hardware node, and a device node that applications see.
--
-- Why: applications then talk to the loopback instead of the hardware, so
-- the hardware node stays free for Valve's filter chains, and the loopback
-- carries the card's own identity (device.id, card.profile.device), which is
-- how Steam recognizes the built-in speakers and microphone and shows its
-- own localized names for them.
--
-- Upstream WirePlumber has no such feature; the logic here follows Valve's
-- CreateLoopback() one to one, with fallbacks for the channel layout in case
-- the hardware node does not carry it.

log = Log.open_topic ("s-io-loopback")

loopbacks = {}

function create_loopback (props)
  local name = props["node.name"]
  local desc = props["node.description"] or name
  local media_class = props["media.class"]
  local channels = props["audio.channels"] or 2
  local position = props["audio.position"] or "[ FL FR ]"
  local pri_session = tonumber (props["priority.session"] or 0) + 1
  local stream_media_class

  if media_class == "Audio/Sink" then
    stream_media_class = "Stream/Output/Audio"
  elseif media_class == "Audio/Source" then
    stream_media_class = "Stream/Input/Audio"
  else
    return nil
  end

  local stream_props = Json.Object {
    ["node.name"] = string.format ("alsa_loopback_stream.%s", name),
    ["node.description"] = string.format ("ALSA internal stream for %s", desc),
    ["media.class"] = stream_media_class,
    ["audio.channels"] = channels,
    ["audio.position"] = position,
    ["alsa.loopback"] = true,
    ["node.passive"] = true,
    ["node.dont-fallback"] = true,
    ["node.linger"] = true,
    ["target.object"] = name,
  }

  local device_props = Json.Object {
    ["node.name"] = string.format ("alsa_loopback_device.%s", name),
    ["node.description"] = desc,
    ["node.virtual"] = false,
    ["media.class"] = media_class,
    ["audio.channels"] = channels,
    ["audio.position"] = position,
    ["alsa.loopback"] = true,
    ["device.id"] = props["device.id"],
    ["card.profile.device"] = props["card.profile.device"],
    ["priority.session"] = pri_session,
    ["session.suspend-timeout-seconds"] = props["session.suspend-timeout-seconds"],
  }

  local args
  if media_class == "Audio/Sink" then
    args = Json.Object {
      ["playback.props"] = stream_props,
      ["capture.props"] = device_props,
    }
  else
    args = Json.Object {
      ["playback.props"] = device_props,
      ["capture.props"] = stream_props,
    }
  end

  log:info (string.format (
      "loopback for %s (%s, %s channels, device.id %s)",
      name, media_class, tostring (channels),
      tostring (props["device.id"])))

  return LocalModule ("libpipewire-module-loopback", args:get_data (), {})
end

om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.create-loopback", "=", "true", type = "pw" },
    Constraint { "alsa.loopback", "-", type = "pw" },
  }
}

om:connect ("object-added", function (_, node)
  local id = node["bound-id"]
  if loopbacks[id] then
    return
  end
  local lb = create_loopback (node.properties)
  if lb then
    loopbacks[id] = lb
  else
    log:warning ("no loopback for node " .. tostring (id))
  end
end)

om:connect ("object-removed", function (_, node)
  loopbacks[node["bound-id"]] = nil
end)

om:activate ()
