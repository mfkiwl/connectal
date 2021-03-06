// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


/* rfreqDataWrite data is FixedPoint(2,14) */
/* setCoeff data is FixedPoint(2, 23) */
interface ChannelSelectTestRequest;
   method Action rfreqDataWrite(Bit#(32) dataRe, Bit#(32) dataIm);
   method Action setCoeff(Bit#(11) addr, Bit#(32) valueRe, Bit#(32) valueIm);
   method Action setPhaseAdvance(Bit#(32) i, Bit#(32) f);
endinterface


/* rfreqDataWrite data is FixedPoint(2,14) */
interface ChannelSelectTestIndication;
   method Action ifreqData(Bit#(32) dataRe, Bit#(32) dataIm);
   method Action setDataResp();
   method Action setConfigResp();
endinterface



