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

#include <stdio.h>
#include "GeneratedTypes.h"
#include <python2.7/Python.h>

static PyObject *heardCallback[20];
static PortalInternal erequest, eindication;

extern "C" {
void jcabozo(PyObject *param, int ind)
{
    Py_INCREF(param);
    heardCallback[ind] = param;
}

static void heard_cb(struct PortalInternal *p,uint32_t v) {
    PyGILState_STATE gstate = PyGILState_Ensure();
    PyEval_CallFunction(heardCallback[0], "(i)", v, NULL);
    PyGILState_Release(gstate);
}
static void heard2_cb(struct PortalInternal *p,uint32_t a, uint32_t b) {
    PyGILState_STATE gstate = PyGILState_Ensure();
    PyEval_CallFunction(heardCallback[1], "(ii)", a, b);
    PyGILState_Release(gstate);
}
static EchoIndicationCb EchoInd_cbTable = { heard_cb, heard2_cb};

void *trequest()
{
    init_portal_internal(&erequest, IfcNames_EchoRequest, NULL, NULL, NULL, NULL, EchoRequest_reqinfo);
    return &erequest;
}
void *tindication()
{
    init_portal_internal(&eindication, IfcNames_EchoIndication,
        EchoIndication_handleMessage, &EchoInd_cbTable, NULL, NULL, EchoIndication_reqinfo);
    return &eindication;
}
} // extern "C"