/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
//import SpecialFIFOs::*;
//import Vector::*;
//import BuildVector::*;
//import StmtFSM::*;
//import FIFO::*;
//import BRAM::*;
//import DefaultValue::*;
//import Connectable::*;
//import CtrlMux::*;
//import Portal::*;
//import ConnectalMemory::*;
//import MemTypes::*;
//import MemServer::*;
//import MemServerInternal::*;
//import MMU::*;
//import MemreadEngine::*;
//import MemwriteEngine::*;
//import HostInterface::*;
//import MMURequest::*;
//import StrstrRequest::*;
//import MemServerIndication::*;
//import MMUIndication::*;
//import StrstrIndication::*;
//import NandSimNames::*;
//import Strstr::*;
import AuroraCommon::*;
//import FlashTop::*;
//import ControllerTypes::*;
//import FlashRequest::*;
//import FlashIndication::*;

interface Top_Pins;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface