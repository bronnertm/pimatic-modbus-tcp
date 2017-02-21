# #my-plugin configuration options
# Declare your config option for your plugin here. 
module.exports = {
  title: "modbus-tcp-config-schema config"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug message to the pimatic log"
      type: "boolean"
      default: false
    }
