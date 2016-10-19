# -*- coding: ascii
require 'rmodbus'

describe ModBus::TCPServer do
  before :all do
    unit_ids = (1..247).to_a.shuffle
    valid_unit_id = unit_ids.first
    @invalid_unit_id = unit_ids.last
    @server = ModBus::TCPServer.new(8502, valid_unit_id)
    @server.coils = [1,0,1,1]
    @server.discrete_inputs = [1,1,0,0]
    @server.holding_registers = [1,2,3,4]
    @server.input_registers = [1,2,3,4]
    @server.start
    @cl = ModBus::TCPClient.new('127.0.0.1', 8502)
    @cl.read_retries = 1
    @slave = @cl.with_slave(valid_unit_id)
  end

  it "should succeed if UID is broadcast" do
    @cl.with_slave(0).read_coils(1,3)
  end

  it "should fail if UID is mismatched" do
    lambda { @cl.with_slave(@invalid_unit_id).read_coils(1,3) }.should raise_exception(
      ModBus::Errors::ModBusTimeout
    )
  end

  it "should send exception if function not supported" do
    lambda { @slave.query('0x43') }.should raise_exception(
      ModBus::Errors::IllegalFunction,
      "The function code received in the query is not an allowable action for the server"
    )
  end

  it "should send exception if quanity of registers are more than 0x7d" do
    lambda { @slave.read_holding_registers(0, 0x7e) }.should raise_exception(
      ModBus::Errors::IllegalDataValue,
      "A value contained in the query data field is not an allowable value for server"
    )
  end

  it "shouldn't send exception if quanity of coils are more than 0x7d0" do
    lambda { @slave.read_coils(0, 0x7d1) }.should raise_exception(
      ModBus::Errors::IllegalDataValue,
      "A value contained in the query data field is not an allowable value for server"
    )
  end

  it "should send exception if addr not valid" do
    lambda { @slave.read_coils(2, 8) }.should raise_exception(
      ModBus::Errors::IllegalDataAddress,
      "The data address received in the query is not an allowable address for the server"
    )
  end

  it "should calc a many requests" do
    @slave.read_coils(1,2)
    @slave.write_multiple_registers(0,[9,9,9,])
    @slave.read_holding_registers(0,3).should == [9,9,9]
  end

  it "should supported function 'read coils'" do
    @slave.read_coils(0,3).should == @server.coils[0,3]
  end

  it "should supported function 'read coils' with more than 125 in one request" do
    @server.coils = Array.new( 1900, 1 )
    @slave.read_coils(0,1900).should == @server.coils[0,1900]
  end

  it "should supported function 'read discrete inputs'" do
    @slave.read_discrete_inputs(1,3).should == @server.discrete_inputs[1,3]
  end

  it "should supported function 'read holding registers'" do
    @slave.read_holding_registers(0,3).should == @server.holding_registers[0,3]
  end

  it "should supported function 'read input registers'" do
    @slave.read_input_registers(2,2).should == @server.input_registers[2,2]
  end

  it "should supported function 'write single coil'" do
    @server.coils[3] = 0
    @slave.write_single_coil(3,1)
    @server.coils[3].should == 1
  end

  it "should supported function 'write single register'" do
    @server.holding_registers[3] = 25
    @slave.write_single_register(3,35)
    @server.holding_registers[3].should == 35
  end

  it "should supported function 'write multiple coils'" do
    @server.coils = [1,1,1,0, 0,0,0,0, 0,0,0,0, 0,1,1,1]
    @slave.write_multiple_coils(3, [1, 0,1,0,1, 0,1,0,1])
    @server.coils.should == [1,1,1,1, 0,1,0,1, 0,1,0,1, 0,1,1,1]
  end

  it "should supported function 'write multiple registers'" do
    @server.holding_registers = [1,2,3,4,5,6,7,8,9]
    @slave.write_multiple_registers(3,[1,2,3,4,5])
    @server.holding_registers.should == [1,2,3,1,2,3,4,5,9]
  end

  it "should have options :host" do
    host = '192.168.0.1'
    srv = ModBus::TCPServer.new(1010, 1, :host => '192.168.0.1')
    srv.host.should eql(host)
  end

  it "should have options :max_connection" do
    max_conn = 5
    srv = ModBus::TCPServer.new(1010, 1, :max_connection => 5)
    srv.maxConnections.should eql(max_conn)
  end

  after :all do
    @cl.close unless @cl.closed?
    @server.stop unless @server.stopped?
    while GServer.in_service?(8502)
      sleep(0.01)
    end
    @server.stop
  end
end
