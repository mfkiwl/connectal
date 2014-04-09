// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import MemServer::*;
import Leds::*;
import DmaUtils::*;

// generated by tool
import MemreadRequestWrapper::*;
import DmaConfigWrapper::*;
import MemreadIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memread::*;

typedef enum {MemreadIndication, MemreadRequest, DmaIndication, DmaConfig} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth)) 

   provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, ObjectOffsetSize),
	    Add#(f__, addrWidth, 40));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(DmaIndication);
   // see comments in testmemread.cpp about buffering requirements
`ifdef ZYNQ
   DmaReadBuffer#(64, 32)   dma_read_buff <- mkDmaReadBuffer();
`else
`ifdef PCIE
   DmaReadBuffer#(64, 64)   dma_read_buff <- mkDmaReadBuffer();
`else
   DmaReadBuffer#(64, 32)   dma_read_buff <- mkDmaReadBuffer();
`endif
`endif
   Vector#(1,  ObjectReadClient#(64))   readClients = cons(dma_read_buff.dmaClient, nil);
   MemServer#(addrWidth, 64)   dma <- mkMemServerOO(dmaIndicationProxy.ifc, readClients, nil);
   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(DmaConfig,dma.request);

   MemreadIndicationProxy memreadIndicationProxy <- mkMemreadIndicationProxy(MemreadIndication);
   MemreadRequest memreadRequest <- mkMemread(memreadIndicationProxy.ifc, dma_read_buff.dmaServer);
   MemreadRequestWrapper memreadRequestWrapper <- mkMemreadRequestWrapper(MemreadRequest,memreadRequest);

   Vector#(4,StdPortal) portals;
   portals[0] = memreadRequestWrapper.portalIfc;
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface master = dma.master;
   interface leds = default_leds;
      
endmodule : mkPortalTop
