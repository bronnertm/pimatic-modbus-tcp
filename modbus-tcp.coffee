# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the [bluebird](https://github.com/petkaantonov/bluebird) promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'
  
  # Include you own depencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #  
  net = require 'net'
  modbus = require("modbus-tcp")
  
  modbusClient = modbus.Client()

  # ###MyPlugin class
  # Create a class that extends the Plugin class and implements the following functions:
  class ModbusTCP extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      
      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("ModbusTCPValue", {
        configDef: deviceConfigDef.ModbusValue, 
        createCallback: (config) => new ModbusTCPValue(config)
      })
      @debug = @config.debug
      @sessions = []

    getConnection: (host, port) =>
      if typeof @sessions[host + "_" + port] is 'undefined'
        env.logger.debug "Create Connection to " + host + ":" +  port
        client = net.createConnection(port, host, @connCallback.bind(this))
        modbusClient = new modbus.Client()
        modbusClient.writer().pipe(client)
        client.pipe(modbusClient.reader())     

        client.on('close', @closeCallback.bind(this,  host + "_" + port))
        client.on('error', @errorCallback.bind(this,  host + "_" + port))
        client.on('end', @endCallback.bind(this,  host + "_" + port))  

        @sessions[host + "_" + port] = modbusClient
        return modbusClient
      

      return @sessions[host + "_" + port]

      

    # connection end callback
    endCallback: (arrayKey)->
      env.logger.debug("End") if @debug
      if @.sessions.hasOwnProperty(arrayKey)
        delete @.sessions[arrayKey]


    # connection error callback
    errorCallback: (arrayKey,error) ->
      env.logger.debug("Error: "+error) if @debug
      console.log error
      console.log arrayKey
      if @.sessions.hasOwnProperty(arrayKey)
        delete @.sessions[arrayKey]

    # connection close callback
    closeCallback: (arrayKey,has_error ) ->
      env.logger.debug("Closed: "+has_error) if @debug
      if @.sessions.hasOwnProperty(arrayKey)
        delete @.sessions[arrayKey]

    # connection connected callback
    connCallback: (socket) ->
      env.logger.debug("Connected") if @debug
      @isConnected = true



  # ###ModbusTCPValue class
  # This class creates the Modbus Reader device
  class ModbusTCPValue extends env.devices.Device

    constructor: (@config) ->
      @name = @config.name
      @id = @config.id

      @interval = 1000 * @config.interval

      @readVal = null

      @_scheduleUpdate()
      @attributes = {}
      switch @config.displayreturntype
        when 'Temperature'
          @attributes.temperature = {
            label: "Temperature"
            description: "the measured temperature"
            type: "number"
            unit: '°C'
            acronym: 'T'
}  
        when 'Number'
          @attributes.number = {
            label: "Number"
            description: "the requested number"
            type: "number"
            unit: ''
            acronym: ''
}  
        when 'Rpm'
          @attributes.rpm = {
            label: "RPM"
            description: "the measured rpm"
            type: "number"
            unit: 'RPM'
            acronym: ''
}  


      super()

    getTemperature: () ->
      return if @modbusvalue? then Promise.resolve(@modbusvalue)

    getNumber: () ->
      return if @modbusvalue? then Promise.resolve(@modbusvalue)

    getRpm: () ->
      return if @modbusvalue? then Promise.resolve(@modbusvalue)

    getConnection: () ->
      @modbusClient = ModbusTCP.getConnection(@config.host, @config.port)

    query: () ->
      @modbusClient =  @getConnection()

      @modbusClient.readHoldingRegisters(@config.unitid, @config.address, @_getReadCount(),(err,coil) =>       
        @modbusvalue = @_doConvert(coil)
        switch @config.displayreturntype
          when 'Temperature'
            @emit "temperature", @modbusvalue
          when 'Number'
            @emit "number", @modbusvalue
          when 'Rpm'
            @emit "rpm", @modbusvalue
        return @readVal
)

    _getReadCount: ()->
      switch @config.returntype
        when 'UINT32' then return @config.address + 1
        when 'INT32' then return @config.address + 1 
        when 'FLOAT' then return @config.address + 1  
        when 'UINT16' then return @config.address
        when 'INT16' then return @config.address

    _doConvert:(data)->
      switch @config.returntype
        when 'UINT32'  
          return @_toUInt32(data)
        when 'INT32'  
          return @_toInt32(data)
        when 'FLOAT' 
          return Number((@_toFloat(data)).toFixed(2)) 
        when 'INT16' 
          return Number(data[0].readInt16BE())
        when 'UINT16' 
          return Number(data[0].readUInt16BE())

    _scheduleUpdate: ->
      unless typeof @intervalObject is 'undefined'
        clearInterval(@intervalObject)

      @intervalObject = setInterval((=>
        @query()),
        @interval
)
    _toUInt32: (toCombine) ->
      buf = Buffer.concat([toCombine[1],toCombine[0]])
      return buf.readUInt32BE();

    _toInt32: (toCombine) ->
      buf = Buffer.concat([toCombine[1],toCombine[0]])
      return buf.readInt32BE();

    _toFloat: (toCombine) ->
      buf = Buffer.concat([toCombine[1],toCombine[0]])
      return buf.readFloatBE(0);

    destroy: () ->
      clearInterval(@intervalObject)
      super()

      #modbusClient
  # ###Finally
  # Create a instance of my plugin
  ModbusTCP = new ModbusTCP
  # and return it to the framework.
  return ModbusTCP
