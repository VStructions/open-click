#
#------------------------------------------------------------------------------
#MIT License
#Copyright (c) 2021 VStructions
#Permission is hereby granted, free of charge, to any person obtaining a copy of
#this software and associated documentation files (the "Software"), to deal in
#the Software without restriction, including without limitation the rights to
#use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
#of the Software, and to permit persons to whom the Software is furnished to do
#so, subject to the following conditions:
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.
#------------------------------------------------------------------------------
#

import keyboard, mouse
import time, socket, signal, sys, os
from collections import defaultdict

"""
TODO add sensitivity control

Capping each UDP packet to 1024 bytes.
Strings in utf-8 means 1-4 bytes, therefore, for speed and safety, each packet can have up to 256 characters.
The first Bytes will be a header signifying the type of data SOO:

[UDP PACKET CARGO] 
{
    HEADER (3 characters)
    DATA (253 characters)
}

Header is a number:
1 - Mouse event
2 - Keyboard event
3 - Macro button  -- TBImplemented

Data is text dependent on header type:
For mouse event - explicit coordinates, encoded mouse actions (eg. click, double click, zoom, ...)
For keyboard event - text
For macro button - encoded macro action (eg. Enter, shutdown, ...)
"""

def initSocket() :
    UDP_IP = get_IP()
    UDP_PORT = 42069

    print(f"Connect to: {UDP_IP}")
    print("  If you are already connected, just restart the client")

    remoteLink = socket.socket(socket.AF_INET, # Internet
                        socket.SOCK_DGRAM) # UDP
    remoteLink.bind((UDP_IP, UDP_PORT))

    return remoteLink

def get_IP():  #By user "fatal_error" who answered on https://stackoverflow.com/questions/166506/finding-local-ip-addresses-using-pythons-stdlib
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def remoteClient() :
    switch = defaultdict(defaultAction)
    switch["11 "] = screenTouchPointers
    switch["12 "] = mouseDrag
    switch["13 "] = mouseLeftClickDownUp
    switch["14 "] = mouseRightClickDownUp
    switch["15 "] = mouseLeftClick
    switch["16 "] = mouseRightClick 
    switch["17 "] = mouseLeftDoubleTapHold
    switch["18 "] = twoFingerTouchGesture
    switch["21 "] = keyboardWrite
    switch["22 "] = keyboardSpecialKeys
    twoFingerTouchGestures[0] = twoFingerGestureIdentifier 
    twoFingerTouchGestures[1] = zoomInOut
    twoFingerTouchGestures[2] = scroll
 
    remoteLink = initSocket()
    firstAndOnlyController = None

    while True:
        try :	        
            data, addr = remoteLink.recvfrom(1024) # buffer size is 1024 bytes
        except KeyboardInterrupt:
            return

        if firstAndOnlyController == addr[0] :
            data = data.decode('Utf-8')
            #print(data)
            try :
                switch[data[:3]](data[3:])
            except TypeError:
                switch.pop(data[:3])

        elif firstAndOnlyController == None :    
            firstAndOnlyController = addr[0]
            data = data.decode('Utf-8')
            try :
                switch[data[:3]](data[3:])
            except TypeError:
                switch.pop(data[:3])



#TODO Find a better place to put these
mouseVectorProducer = [[],[]]
ScrollVectorProducer = [[],[]]
zoomMemory = [0.0,0.0]

#twoFingerTouchCoordMemory = [[],[]]
#twoFingerTouchVectorMomentum = [0.0,0.0]
twoFingerTouchVectorCounter = 0
twoFingerTouchGestures = {}
twoFingerGestureIdentified = 0

mouseButtonState = {"Left" : 0, "Right" : 0, "LeftScreenHeld" : 0}
#touchScreenState need to know how many fingers are on screen
touchScreenState = {"one" : 0, "two" : 0}
#TODO Find a better place to put these 

def defaultAction() :
    return

def mouseDrag(coords) :
    if touchScreenState["one"] == 1 :
        mouseVectorProducer[0] = mouseVectorProducer[1]
        mouseVectorProducer[1] = [float(coordPart) for coordPart in coords[1:-1].split(',')] #TODO make floating safer

        if mouseVectorProducer[0] and mouseVectorProducer[1] :    
            xVector = (mouseVectorProducer[1][0] - mouseVectorProducer[0][0]) * 5 #Real vector and sensitivity!
            yVector = (mouseVectorProducer[1][1] - mouseVectorProducer[0][1]) * 5
            mouse.move(xVector, yVector, absolute=False)
        #TODO Implement some sort of acceleration for veeery slow movements

    #print(f"Pan: {coords[1:-1]}")
    return

def mouseLeftClickDownUp(data) :
    mouseButtonState["Left"] = mouseButtonState["Left"] ^ 1
    if mouseButtonState["Left"] == 0 :
        mouse.release(button="left")
    else :
        mouse.hold(button="left")
    return

def mouseRightClickDownUp(data) :
    mouseButtonState["Right"] = mouseButtonState["Right"] ^ 1
    if mouseButtonState["Right"] == 0 :
        mouse.release(button="right")
    else :
        mouse.hold(button="right")
    return

def mouseLeftClick(data) :
    mouse.click(button="left")
    return

def mouseRightClick(data) :
    mouse.click(button="right")
    return

def mouseLeftDoubleTapHold(data) :
    mouse.hold(button="left")
    mouseButtonState["LeftScreenHeld"] = 1
    return

def screenTouchPointers(data) :
    #global twoFingerTouchVectorMomentum
    global twoFingerTouchVectorCounter
    global twoFingerGestureIdentified

    if data == "1" :
        touchScreenState["one"] = touchScreenState["one"] ^ 1

        if touchScreenState["one"] == 0 :
            mouseVectorProducer[1] = []
            if mouseButtonState["LeftScreenHeld"] == 1 :
                mouse.release(button="left")
                mouseButtonState["LeftScreenHeld"] = 0
            return

        return

    if data == "2" :
        touchScreenState["one"] = 0
        touchScreenState["two"] = touchScreenState["two"] ^ 1

        if touchScreenState["two"] == 0 :
            twoFingerTouchVectorMomentum = [0.0, 0.0]
            ScrollVectorProducer[1] = []
            twoFingerGestureIdentified = 0
            twoFingerTouchVectorCounter = 0
            zoomCounter = 0
       
    return

def twoFingerTouchGesture(data) :
    global twoFingerGestureIdentified

    if touchScreenState["two"] == 1 :
        twoFingerTouchGestures[twoFingerGestureIdentified](data)

    return

def twoFingerGestureIdentifier(data) :
    #global twoFingerTouchVectorMomentum
    #global twoFingerTouchCoordMemory
    global twoFingerTouchVectorCounter
    global twoFingerGestureIdentified
    
    if touchScreenState["two"] == 1 :
        #twoFingerTouchVectorCounter defines the identification accuracy
        if twoFingerTouchVectorCounter != 3 :

            #Commented out section makes the app differenciate between vertical and horizontal scroll
            #Find the closing parenthesis in the variable length string, var len str because of the numbers, in order to convert to float
            #coordList = [float(coordPart) for coordPart in data[1:(data.index(')'))].split(',')] #Make floating safer

            #twoFingerTouchCoordMemory[0] = twoFingerTouchCoordMemory[1]
            #if twoFingerTouchVectorCounter == 0 :
            #    twoFingerTouchCoordMemory[0] = coordList
            #twoFingerTouchCoordMemory[1] = coordList
            
            #if twoFingerTouchVectorCounter != 0 :   #Create vectors from coordinates and add them = directional momentum
            #    twoFingerTouchVectorMomentum[0] = twoFingerTouchVectorMomentum[0] + twoFingerTouchCoordMemory[1][0] - twoFingerTouchCoordMemory[0][0]
            #    twoFingerTouchVectorMomentum[1] = twoFingerTouchVectorMomentum[1] + twoFingerTouchCoordMemory[1][1] - twoFingerTouchCoordMemory[0][1] 

            if twoFingerTouchVectorCounter == 0 :
                zoomMemory[0] = float(data[15:])
            zoomMemory[1] = float(data[15:])

            twoFingerTouchVectorCounter = twoFingerTouchVectorCounter + 1
        else :
            if (zoomMemory[1] > zoomMemory[0]*1.12) or (zoomMemory[1] < zoomMemory[0]*0.89) : #Some difference also sens
                twoFingerGestureIdentified = 1  #Zoom
            else : 
                twoFingerGestureIdentified = 2  #Scroll

            #elif abs(twoFingerTouchVectorMomentum[1]) > abs(twoFingerTouchVectorMomentum[0]) : #yMomentum > xMomentum  
            #    twoFingerGestureIdentified = Have 2 different Scrolls

            twoFingerTouchVectorMomentum = [0.0, 0.0]
            twoFingerTouchVectorCounter = 0

    return

def scroll(data) :
    if touchScreenState["two"] == 1 :
        ScrollVectorProducer[0] = ScrollVectorProducer[1]
        ScrollVectorProducer[1] = [float(coordPart) for coordPart in data[1:(data.index(')'))].split(',')] #TODO make floating safer

        if ScrollVectorProducer[0] and ScrollVectorProducer[1] :    
            yVector = (ScrollVectorProducer[1][1] - ScrollVectorProducer[0][1]) * 0.04 #Sens
            xVector = (ScrollVectorProducer[1][0] - ScrollVectorProducer[0][0]) * 0.05 #Sens
            mouse.wheel(yVector)    #TODO Allow for inverting
            keyboard.press("shift")
            mouse.wheel(xVector)    #TODO Allow for inverting
            keyboard.release("shift")

    return

def zoomInOut(data) :    
    global zoomMemory

    if touchScreenState["two"] == 1:
        zoomMemory[1] = float(data[15:]) #TODO make floating safer

        if (zoomMemory[1] > zoomMemory[0]*1.1) :
            keyboard.send("ctrl+plus")
            zoomMemory[0] = zoomMemory[1]
        elif (zoomMemory[1] < zoomMemory[0]*0.89) :
            keyboard.send("ctrl+-")
            zoomMemory[0] = zoomMemory[1]
            
    return

def keyboardWrite(data) :
    keyboard.write(data)
    return

def keyboardSpecialKeys(data) :
    keyboard.write(data)
    return

#def horizontalScroll(data) :
#    if touchScreenState["two"] == 1 :
#        ScrollVectorProducer[0] = ScrollVectorProducer[1]
#        ScrollVectorProducer[1] = [float(coordPart) for coordPart in data[1:(data.index(')'))].split(',')] #Make floating safer
#
#        if ScrollVectorProducer[0] and ScrollVectorProducer[1] :    
#            xVector = (ScrollVectorProducer[1][0] - ScrollVectorProducer[0][0]) * 0.05 #Sens
#            keyboard.press("shift")
#            mouse.wheel(-xVector)    #Allow for inverting
#            keyboard.release("shift")
#
#    return 



if __name__ == '__main__':
    remoteClient()
