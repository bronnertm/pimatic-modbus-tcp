module.exports ={
  title: "pimatic-my-plugin device config schemas"
  ModbusValue: 
    title: "Modbus TCP Sensor"
    type: "object"
    properties:
      host:
        description: "Hostname"
        type: "string"
        default: "127.0.0.1"
      port:
        description: "Portnumber"
        type: "number"
        default: 502
      unitid:
        description: "UnitId"
        type: "number"
        default: 0
      address:
        description: "Address"
        type: "number"
        default: 1
      returntype:
        description: "ReturnType"
        type: "string"
        enum: ['UINT32','INT32', 'FLOAT','UINT16','INT16']
      displayreturntype:
        description: "Display Type"
        type: "string"
        enum: ['Temperature', 'Number','Rpm']

      interval:
        description: "How often should the value be read, in seconds"
        type: "number"
        default: 5
          }