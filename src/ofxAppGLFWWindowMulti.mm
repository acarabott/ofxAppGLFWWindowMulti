//
//  ofxAppGLFWWindowMulti.cpp
//
//  Created by Theodore Watson on 1/28/14.
//
//


#include "ofxAppGLFWWindowMulti.h"
#include "ofEvents.h"

#include "ofBaseApp.h"
#include "ofGLProgrammableRenderer.h"
#include "ofAppRunner.h"

#include "Poco/URI.h"

#ifdef TARGET_LINUX
	#include "ofIcon.h"
	#include "ofImage.h"
	#define GLFW_EXPOSE_NATIVE_X11
	#ifndef TARGET_OPENGLES
		#define GLFW_EXPOSE_NATIVE_GLX
	#else
		#define GLFW_EXPOSE_NATIVE_EGL
	#endif
	#include "GLFW/glfw3native.h"
	#include <X11/Xatom.h>
#elif defined(TARGET_OSX)
	#include <Cocoa/Cocoa.h>
	#include <Carbon/Carbon.h>
	#define GLFW_EXPOSE_NATIVE_COCOA
	#define GLFW_EXPOSE_NATIVE_NSGL
	#include "GLFW/glfw3native.h"
#elif defined(TARGET_WIN32)
	#define GLFW_EXPOSE_NATIVE_WIN32
	#define GLFW_EXPOSE_NATIVE_WGL
	#include <GLFW/glfw3native.h>
#endif


//========================================================================
// static variables:

ofBaseApp *	ofxAppGLFWWindowMulti::ofAppPtr;
ofxAppGLFWWindowMulti	* ofxAppGLFWWindowMulti::instance;

void ofGLReadyCallback();

//-------------------------------------------------------
ofxAppGLFWWindowMulti::ofxAppGLFWWindowMulti():ofAppBaseWindow(){
	ofLogVerbose("ofxAppGLFWWindowMulti") << "creating GLFW window";
	bEnableSetupScreen	= true;
	buttonInUse			= 0;
	buttonPressed		= false;
    bMultiWindowFullscreen  = false;

	samples				= 0;
	rBits=gBits=bBits=aBits = 8;
	depthBits			= 24;
	stencilBits			= 0;

	orientation 		= OF_ORIENTATION_DEFAULT;

	bDoubleBuffered		= true;

	ofAppPtr			= NULL;
	instance			= this;

	glVersionMinor=glVersionMajor=-1;
	nFramesSinceWindowResized = 0;

    addWindow("main window", 0, 0, 1024, 768);

    currentWindow = 0;

    focusedWindow = 0;

    //default to 4 times antialiasing.
    setNumSamples(4);
	iconSet = false;
    isSetup = false;
}


//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setNumSamples(int _samples){
	samples=_samples;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setMultiDisplayFullscreen(bool bMultiFullscreen){
    bMultiWindowFullscreen = bMultiFullscreen;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setDoubleBuffering(bool doubleBuff){
	bDoubleBuffered = doubleBuff;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setColorBits(int r, int g, int b){
	rBits=r;
	gBits=g;
	bBits=b;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setAlphaBits(int a){
	aBits=a;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setDepthBits(int depth){
	depthBits=depth;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setStencilBits(int stencil){
	stencilBits=stencil;
}


//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setOpenGLVersion(int major, int minor){
	glVersionMajor = major;
	glVersionMinor = minor;
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::addWindow(string windowName, float x, float y, float w, float h, bool bFullscreen){

        shared_ptr <AppGLFWSingleWindow> winPtr( new AppGLFWSingleWindow() );
        winPtr->windowNo = windows.size();
        winPtr->windowName = windowName;

        if( windows.size() >= 1 ){

            if( isSetup ){
                winPtr->windowPtr = glfwCreateWindow(w, h, windowName.c_str(), NULL, windows[0]->windowPtr);



                if( pushWindow(winPtr->windowNo) ){

                    setWindowTitle(windowName);
                    setWindowShape(w, h);
                    setWindowPosition(x, y);
                    setFullscreen(bFullscreen);

                    popWindow();
                }

            }else{
                winPtr->windowName = windowName;
                winPtr->windowBounds.set(x, y, w, h);
                winPtr->bFullscreen = bFullscreen;
            }

        }else{
            winPtr->bMainWindow = true;
        }

        windows.push_back( winPtr );

        if( isSetup ){
            initializeWindow();
        }
        setFocusedWindow(winPtr->windowPtr);

        return winPtr->windowNo;
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::closeWindow(int windowNo){
    if(ofInRange(windowNo, 0, windows.size())){
        if( windows[windowNo]->windowPtr != NULL ){
            glfwDestroyWindow(windows[windowNo]->windowPtr);
            windows[windowNo]->windowPtr = NULL;

            if (windowNo == focusedWindow) {
                focusedWindow = 0;
                // TODO This is ok as long as closing window 0 ends the app,
                // if it's possible to close window 0, and still have other
                // windows open, this is problematic
            }
            if (windowNo == 0) {
                OF_EXIT_APP(0);
            }

            return true;
        }
    } else {
        ofLogError("ofxAppGLFWWindowMulti::closeWindow")
            << "window doesn't exist with windowNo: " << windowNo;
    }

	return false;
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getNumWindows(){
    return windows.size();
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getNumActiveWindows() {

    int totalWins = 0;
    for(int i = 0; i < windows.size(); i++) {
        if( windows[i]->windowPtr != NULL ) {
            totalWins++;
        }
    }
    return totalWins;
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getCurrentWindowNo(){
    return currentWindow;
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getFocusedWindowNo(){
    return focusedWindow;
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::isWindowInFocus(int windowNo){
    return windowNo == getFocusedWindowNo();
}

//------------------------------------------------------------
vector <shared_ptr <AppGLFWSingleWindow> > ofxAppGLFWWindowMulti::getWindows(){
    return windows;
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::pushWindow(int newWindow){
    if( newWindow >= 0 && newWindow < windows.size() ){
        if( windows[newWindow]->windowPtr != NULL ){
            windowStack.push_back(currentWindow);
            currentWindow = newWindow;
            return true;
        }
    }
    return false;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::popWindow(){
    if( windowStack.size() ){

        int newWindow = windowStack.back();
        if( newWindow >= 0 && newWindow < windows.size() ){
            if( windows[newWindow]->windowPtr != NULL ){
                currentWindow = newWindow;
            }else{
                currentWindow = 0;
            }
        }
        windowStack.pop_back();
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setupOpenGL(int w, int h, int screenMode){

	if(!glfwInit( )){
		ofLogError("ofxAppGLFWWindowMulti") << "couldn't init GLFW";
		return;
	}

	if(screenMode==OF_GAME_MODE){
        ofLogError("ofxAppGLFWWindowMulti") << "can't do game mode";
        return;
	}

    windows[0]->bFullscreen = (screenMode == OF_FULLSCREEN);

//	ofLogNotice("ofxAppGLFWWindowMulti") << "WINDOW MODE IS " << screenMode;

	glfwWindowHint(GLFW_RED_BITS, rBits);
	glfwWindowHint(GLFW_GREEN_BITS, gBits);
	glfwWindowHint(GLFW_BLUE_BITS, bBits);
	glfwWindowHint(GLFW_ALPHA_BITS, aBits);
	glfwWindowHint(GLFW_DEPTH_BITS, depthBits);
	glfwWindowHint(GLFW_STENCIL_BITS, stencilBits);
	glfwWindowHint(GLFW_SAMPLES,samples);

#ifndef TARGET_OSX
	glfwWindowHint(GLFW_AUX_BUFFERS,bDoubleBuffered?1:0);
#endif

	if(glVersionMinor!=-1 && glVersionMajor!=-1){
		glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, glVersionMajor);
		glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, glVersionMinor);
		if(glVersionMajor>=3){
			glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
			glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
		}
		#ifdef TARGET_OPENGLES
		glfwWindowHint(GLFW_CLIENT_API,GLFW_OPENGL_ES_API);
		#endif
	}

	setVerticalSync(false);

    for(int i = 0; i < windows.size(); i++){
        if( windows[i]->windowPtr == NULL ){
            if( i == 0 ){
                windows[i]->windowPtr = glfwCreateWindow(w, h, "", NULL, NULL);

                if(!windows[0]->windowPtr){
                    ofLogError("ofxAppGLFWWindowMulti") << "couldn't create GLFW window";
                    return;
                }

                windows[i]->windowBounds.setWidth(w);
                windows[i]->windowBounds.setHeight(h);

            }else{
                windows[i]->windowPtr = glfwCreateWindow(windows[i]->windowBounds.getWidth(), windows[i]->windowBounds.getHeight(), windows[i]->windowName.c_str(), NULL, windows[0]->windowPtr);
            }
        }
    }


    for(int i = 0; i < windows.size(); i++){

        glfwMakeContextCurrent(windows[i]->windowPtr);

        if( pushWindow(windows[i]->windowNo) ){
            if( windows[i]->bFullscreen ){
                //so that setFullscreen doesn't think its been set already
                windows[i]->bFullscreen = false;

                //need to move to the right window first
                setWindowPosition(windows[i]->windowBounds.x, windows[i]->windowBounds.y);
                setFullscreen(true);
           }else{
                //shape first because of a bug with OS X
                setWindowShape(windows[i]->windowBounds.width, windows[i]->windowBounds.height);
                setWindowTitle(windows[i]->windowName.c_str());
            }

            popWindow();
        }

        //update our window info
        updateWindowSize(i);
        getWindowPosition();
    }

    glfwMakeContextCurrent(windows[0]->windowPtr);

    isSetup = true;
    ofGLReadyCallback();
}

//--------------------------------------------
void ofxAppGLFWWindowMulti::exit_cb(GLFWwindow* windowP_){
	OF_EXIT_APP(0);
}

//--------------------------------------------
void ofxAppGLFWWindowMulti::close_cb(GLFWwindow* windowP_){
    for(int i = 0; i < instance->windows.size(); i++){
        if( instance->windows[i]->windowPtr == windowP_ ){
            instance->windows[i]->windowPtr = NULL;
        }
    }
    glfwDestroyWindow(windowP_);
    windowP_ = NULL;
}

//--------------------------------------------
void ofxAppGLFWWindowMulti::initializeWindow(){
	 //----------------------
	 // setup the callbacks

    for(int i = 0; i < windows.size(); i++){
        if( windows[i]->bInitialized ||windows[i]->windowPtr == NULL)continue;
        windows[i]->bInitialized = true;

        if( i == 0 ){
            glfwSetWindowCloseCallback(windows[i]->windowPtr, exit_cb);
        }else{
            glfwSetWindowCloseCallback(windows[i]->windowPtr, close_cb);
        }

        glfwSetMouseButtonCallback(windows[i]->windowPtr, mouse_cb);
        glfwSetCursorPosCallback(windows[i]->windowPtr, motion_cb);

        glfwSetKeyCallback(windows[i]->windowPtr, keyboard_cb);
        glfwSetWindowSizeCallback(windows[i]->windowPtr, resize_cb);
        glfwSetScrollCallback(windows[i]->windowPtr, scroll_cb);
        glfwSetDropCallback(windows[i]->windowPtr, drop_cb);
        glfwSetWindowFocusCallback(windows[i]->windowPtr, focus_cb);
    }
}

#ifdef TARGET_LINUX
//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowIcon(const string & path){
    ofPixels iconPixels;
	ofLoadImage(iconPixels,path);
	setWindowIcon(iconPixels);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowIcon(const ofPixels & iconPixels){
	iconSet = true;
	int length = 2+iconPixels.getWidth()*iconPixels.getHeight();
	unsigned long * buffer = new unsigned long[length];
	buffer[0]=iconPixels.getWidth();
	buffer[1]=iconPixels.getHeight();
	for(int i=0;i<iconPixels.getWidth()*iconPixels.getHeight();i++){
		buffer[i+2] = iconPixels[i*4+3]<<24;
		buffer[i+2] += iconPixels[i*4]<<16;
		buffer[i+2] += iconPixels[i*4+1]<<8;
		buffer[i+2] += iconPixels[i*4];
	}

	XChangeProperty(getX11Display(), getX11Window(), XInternAtom(getX11Display(), "_NET_WM_ICON", False), XA_CARDINAL, 32,
						 PropModeReplace,  (const unsigned char*)buffer,  length);
	XFlush(getX11Display());
}
#endif

//--------------------------------------------
void ofxAppGLFWWindowMulti::runAppViaInfiniteLoop(ofBaseApp * appPtr){
	ofAppPtr = appPtr;


	ofNotifySetup();
	while(true){
        for(int i = 0; i < windows.size(); i++){
            //skip closed windows
            if( windows[i]->windowPtr == NULL ) continue;

            glfwMakeContextCurrent(windows[i]->windowPtr);

            currentWindow = i;
            if( currentWindow == 0 ){
                ofNotifyUpdate();
            }
            currentWindow = i;
            display(windows[currentWindow]->windowPtr);
            currentWindow = i;
        }
        currentWindow = 0;
	}
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::display(GLFWwindow* window){


	// set viewport, clear the screen
	ofViewport();		// used to be glViewport( 0, 0, width, height );
	float * bgPtr = ofBgColorPtr();
	bool bClearAuto = ofbClearBg();

	// to do non auto clear on PC for now - we do something like "single" buffering --
	// it's not that pretty but it work for the most part

	#ifdef TARGET_WIN32
	if (bClearAuto == false){
		glDrawBuffer (GL_FRONT);
	}
	#endif

	if ( bClearAuto == true ){
		ofClear(bgPtr[0]*255,bgPtr[1]*255,bgPtr[2]*255, bgPtr[3]*255);
	}

	if( bEnableSetupScreen )ofSetupScreen();

    //we do this because the framecounter is otherwise incremented twice;
    if(currentWindow == 0){
        ofNotifyDraw();
    }else{
        ofAppPtr->draw();
    }


	#ifdef TARGET_WIN32
	if (bClearAuto == false){
		// on a PC resizing a window with this method of accumulation (essentially single buffering)
		// is BAD, so we clear on resize events.
		if (nFramesSinceWindowResized < 3){
			ofClear(bgPtr[0]*255,bgPtr[1]*255,bgPtr[2]*255, bgPtr[3]*255);
		} else {
			if ( (ofGetFrameNum() < 3 || nFramesSinceWindowResized < 3) && bDoubleBuffered ){
                glfwSwapBuffers(window);
			}else{
                glFlush();
            }
        }
	} else {
		if(bDoubleBuffered){
		    glfwSwapBuffers(window);
		} else {
			glFlush();
		}
	}
	#else
		if (bClearAuto == false){
			// in accum mode resizing a window is BAD, so we clear on resize events.
			if (nFramesSinceWindowResized < 3){
				ofClear(bgPtr[0]*255,bgPtr[1]*255,bgPtr[2]*255, bgPtr[3]*255);
			}
		}
		if(bDoubleBuffered){
		    glfwSwapBuffers(window);
		} else{
			glFlush();
		}
	#endif


	nFramesSinceWindowResized++;
	glfwPollEvents();
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowTitle(int windowNo, string title){
    if (ofInRange(windowNo, 0, windows.size())) {
        windows[windowNo]->windowName = title;
        glfwSetWindowTitle(windows[windowNo]->windowPtr,title.c_str());
    } else {
        ofLogError("ofxAppGLFWWindowMulti::setWindowTitle")
            << "window doesn't exist with windowNo: " << windowNo;
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowTitle(string title){
    setWindowTitle(currentWindow, title);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::updateWindowSize(int windowNo) {
    if(ofInRange(windowNo, 0, windows.size())) {
        int windowW, windowH;
        glfwGetWindowSize(windows[windowNo]->windowPtr,&windowW,&windowH);

        if( windows[windowNo]->bFullscreen == false ){
            windows[windowNo]->windowBounds.width  = windowW;
            windows[windowNo]->windowBounds.height = windowH;
        }else{
            windows[windowNo]->fullScreenBounds.width  = windowW;
            windows[windowNo]->fullScreenBounds.height = windowH;
        }

        return ofPoint(windowW, windowH);
    }

    ofLogError("ofxAppGLFWWindowMulti::updateWindowSize")
        << "window doesn't exist with windowNo: " << windowNo;

    return ofPoint(0,0);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getWindowSize(){
    return updateWindowSize(currentWindow);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getWindowSize(int windowNo){
    return updateWindowSize(windowNo);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getWindowPosition(int windowNo){
    if(ofInRange(windowNo, 0, windows.size())) {
        int x, y;
        glfwGetWindowPos(windows[windowNo]->windowPtr, &x, &y);

        if( windows[windowNo]->bFullscreen == false ){
            windows[windowNo]->windowBounds.x = x;
            windows[windowNo]->windowBounds.y = y;
        }else{
            windows[windowNo]->fullScreenBounds.x = x;
            windows[windowNo]->fullScreenBounds.y = y;
        }

        return ofPoint(x,y,0);
    }

    ofLogError("ofxAppGLFWWindowMulti::getWindowPosition")
        << "window doesn't exist with windowNo: " << windowNo;

    return ofPoint(0,0,0);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getWindowPosition(){
    return getWindowPosition(currentWindow);
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getWindowMonitor(int windowNo){
    if(ofInRange(windowNo, 0, windows.size())) {
        int numberOfMonitors;
        GLFWmonitor** monitors = glfwGetMonitors(&numberOfMonitors);

        int xW;	int yW;
        glfwGetWindowPos(windows[windowNo]->windowPtr, &xW, &yW);

        for (int iC=0; iC < numberOfMonitors; iC++){
            int xM; int yM;
            glfwGetMonitorPos(monitors[iC], &xM, &yM);
            const GLFWvidmode * desktopMode = glfwGetVideoMode(monitors[iC]);
            ofRectangle monitorRect(xM, yM, desktopMode->width, desktopMode->height);

            //we have to do this so the inside returns true for a window going fullscreen on that monitor
            if( xW == xM ){
                xW += 1;
            }
            if( yW == yM ){
                yW += 1;
            }

            if (monitorRect.inside(xW, yW)){
                return iC;
            }
        }

    }

    ofLogError("ofxAppGLFWWindowMulti::getWindowMonitor")
        << "window doesn't exist with windowNo: " << windowNo;

    return 0;
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getCurrentMonitor(){
    return getWindowMonitor(currentWindow);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getScreenSize(int windowNo){
    if(ofInRange(windowNo, 0, windows.size())) {
        int count;
        GLFWmonitor** monitors = glfwGetMonitors(&count);
        if(count>0){
            int winMonitor = getWindowMonitor(windowNo);
            const GLFWvidmode * desktopMode = glfwGetVideoMode(monitors[winMonitor]);
            if(desktopMode){
                if( orientation == OF_ORIENTATION_DEFAULT || orientation == OF_ORIENTATION_180 ){
                    return ofPoint(desktopMode->width, desktopMode->height);
                }
            }
        }
    } else {
        ofLogError("ofxAppGLFWWindowMulti::getScreenSize")
            << "window doesn't exist with windowNo: " << windowNo;
    }

    return ofPoint(0,0);
}

//------------------------------------------------------------
ofPoint ofxAppGLFWWindowMulti::getScreenSize(){
    return getScreenSize(currentWindow);
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getWidth(int windowNo){
    if( orientation == OF_ORIENTATION_DEFAULT || orientation == OF_ORIENTATION_180 ){
        return getWindowSize(windowNo).x;
    }else{
        return getWindowSize(windowNo).y;
    }
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getWidth(){
    return getWidth(currentWindow);
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getHeight(int windowNo){
    if( orientation == OF_ORIENTATION_DEFAULT || orientation == OF_ORIENTATION_180 ){
        return getWindowSize(windowNo).y;
    }else{
        return getWindowSize(windowNo).x;
    }
}

//------------------------------------------------------------
int ofxAppGLFWWindowMulti::getHeight(){
    return getHeight(currentWindow);
}

//------------------------------------------------------------
ofWindowMode ofxAppGLFWWindowMulti::getWindowMode(int windowNo){
    if(ofInRange(windowNo, 0, windows.size())) {
        return ( windows[windowNo]->bFullscreen ? OF_FULLSCREEN : OF_WINDOW );
    }

    ofLogError("ofxAppGLFWWindowMulti::getWindowMode")
        << "window doesn't exist with windowNo: " << windowNo;

    return OF_WINDOW;
}

//------------------------------------------------------------
ofWindowMode ofxAppGLFWWindowMulti::getWindowMode(){
    return getWindowMode(currentWindow);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowPosition(int windowNo, int x, int y){
    if (ofInRange(windowNo, 0, windows.size())) {
        glfwSetWindowPos(windows[windowNo]->windowPtr,x,y);

        if( windows[windowNo]->bFullscreen == false ){
            windows[windowNo]->windowBounds.x = x;
            windows[windowNo]->windowBounds.y = y;
        }
    } else {
        ofLogError("ofxAppGLFWWindowMulti::setWindowPosition")
            << "window doesn't exist with windowNo: " << windowNo;
    }

}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowPosition(int x, int y){
    setWindowPosition(currentWindow, x, x);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowShape(int windowNo, int w, int h){
    if (ofInRange(windowNo, 0, windows.size())) {
        glfwSetWindowSize(windows[windowNo]->windowPtr,w,h);
    } else {
        ofLogError("ofxAppGLFWWindowMulti::setWindowShape")
            << "window doesn't exist with windowNo: " << windowNo;
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setWindowShape(int w, int h){
    setWindowShape(currentWindow, w, h);
}
//------------------------------------------------------------
void ofxAppGLFWWindowMulti::hideCursor(){
	glfwSetInputMode(windows[currentWindow]->windowPtr,GLFW_CURSOR,GLFW_CURSOR_HIDDEN);
};

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::showCursor(){
	glfwSetInputMode(windows[currentWindow]->windowPtr,GLFW_CURSOR,GLFW_CURSOR_NORMAL);
};

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::enableSetupScreen(){
	bEnableSetupScreen = true;
};

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::disableSetupScreen(){
	bEnableSetupScreen = false;
};

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setFullscreen(int windowNo, bool fullscreen){
    if (!ofInRange(windowNo, 0, windows.size())) {
        ofLogError("ofxAppGLFWWindowMulti::setFullScreen")
            << "window doesn't exist with windowNo: " << windowNo;
        return;
    }
    //we only want to change window mode if the requested window is different to the current one.
    bool bChanged = fullscreen != windows[windowNo]->bFullscreen;
    if( !bChanged ){
        return;
    }

    windows[windowNo]->bFullscreen = fullscreen;


#ifdef TARGET_LINUX
#include <X11/Xatom.h>

    Window nativeWin = glfwGetX11Window(windows[windowNo]->windowPtr);
	Display* display = glfwGetX11Display();
	int monitorCount;
	GLFWmonitor** monitors = glfwGetMonitors(&monitorCount);

	if( bMultiWindowFullscreen && monitorCount > 1 ){
		// find the monitors at the edges of the virtual desktop
		int minx=numeric_limits<int>::max();
		int miny=numeric_limits<int>::max();
		int maxx=numeric_limits<int>::min();
		int maxy=numeric_limits<int>::min();
		int x,y,w,h;
		int monitorLeft=0, monitorRight=0, monitorTop=0, monitorBottom=0;
        for(int i = 0; i < monitorCount; i++){
            glfwGetMonitorPos(monitors[i],&x,&y);
            glfwGetMonitorPhysicalSize(monitors[i],&w,&h);
            if(x<minx){
            	monitorLeft = i;
            	minx = x;
            }
            if(y<miny){
            	monitorTop = i;
            	miny = y;
            }
            if(x+w>maxx){
            	monitorRight = i;
            	maxx = x+w;
            }
            if(y+h>maxy){
            	monitorBottom = i;
            	maxy = y+h;
            }

        }

        // send fullscreen_monitors event with the edges monitors
		Atom m_net_fullscreen_monitors= XInternAtom(display, "_NET_WM_FULLSCREEN_MONITORS", false);

		XEvent xev;

		xev.xclient.type = ClientMessage;
		xev.xclient.serial = 0;
		xev.xclient.send_event = True;
		xev.xclient.window = nativeWin;
		xev.xclient.message_type = m_net_fullscreen_monitors;
		xev.xclient.format = 32;

		xev.xclient.data.l[0] = monitorTop;
		xev.xclient.data.l[1] = monitorBottom;
		xev.xclient.data.l[2] = monitorLeft;
		xev.xclient.data.l[3] = monitorRight;
		xev.xclient.data.l[4] = 1;
		XSendEvent(display, RootWindow(display, DefaultScreen(display)),
				   False, SubstructureRedirectMask | SubstructureNotifyMask, &xev);

	}

	// send fullscreen event
	Atom m_net_state= XInternAtom(display, "_NET_WM_STATE", false);
	Atom m_net_fullscreen= XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", false);

	XEvent xev;

	xev.xclient.type = ClientMessage;
	xev.xclient.serial = 0;
	xev.xclient.send_event = True;
	xev.xclient.window = nativeWin;
	xev.xclient.message_type = m_net_state;
	xev.xclient.format = 32;

	if (fullscreen)
		xev.xclient.data.l[0] = 1;
	else
		xev.xclient.data.l[0] = 0;

	xev.xclient.data.l[1] = m_net_fullscreen;
	xev.xclient.data.l[2] = 0;
	xev.xclient.data.l[3] = 0;
	xev.xclient.data.l[4] = 0;
	XSendEvent(display, RootWindow(display, DefaultScreen(display)),
			   False, SubstructureRedirectMask | SubstructureNotifyMask, &xev);

	// tell the window manager to bypass composition for this window in fullscreen for speed
	// it'll probably help solving vsync issues
	Atom m_bypass_compositor = XInternAtom(display, "_NET_WM_BYPASS_COMPOSITOR", False);
	unsigned long value = fullscreen ? 1 : 0;
	XChangeProperty(display, nativeWin, m_bypass_compositor, XA_CARDINAL, 32, PropModeReplace, (unsigned char*)&value, 1);

	XFlush(display);

#elif defined(TARGET_OSX)

    int monitorCount;
    GLFWmonitor** monitors = glfwGetMonitors(&monitorCount);
    int windowMonitor = getWindowMonitor(windowNo);

	if( windows[windowNo]->bFullscreen ){
        ofPoint winPos = getWindowPosition(windowNo);
        ofPoint winSize = getWindowSize(windowNo);

        windows[windowNo]->windowBounds.set(winPos.x, winPos.y,
                                            winSize.x, winSize.y);

		//----------------------------------------------------
        SetSystemUIMode(kUIModeAllHidden,NULL);

		NSWindow * cocoaWindow = glfwGetCocoaWindow(windows[windowNo]->windowPtr);

		[cocoaWindow setStyleMask:NSBorderlessWindowMask];

		ofPoint screenSize = getScreenSize(windowNo);
		ofRectangle allScreensSpace;

        if( bMultiWindowFullscreen && monitorCount > 1 ){

			//calc the sum Rect of all the monitors
			for(int i = 0; i < monitorCount; i++){
				const GLFWvidmode * desktopMode = glfwGetVideoMode(monitors[i]);
				int x, y;
				glfwGetMonitorPos(monitors[i], &x, &y);
				ofRectangle screen = ofRectangle( x, y, desktopMode->width, desktopMode->height );
				allScreensSpace = allScreensSpace.getUnion(screen);
			}
			//for OS X we need to set this first as the window size affects the window positon
			setWindowShape(windowNo, allScreensSpace.width, allScreensSpace.height);
			setWindowPosition(windowNo, allScreensSpace.x, allScreensSpace.y);

        }else if (monitorCount > 1 && windowMonitor < monitorCount){
            int xpos;
			int ypos;
			glfwGetMonitorPos(monitors[windowMonitor], &xpos, &ypos);

            //we do this as setWindowShape affects the position of the monitor
            //normally we would just call setWindowShape first, but on multi monitor you see the window bleed onto the second monitor as it first changes shape and is then repositioned.
            //this first moves it over in X, does the screen resize and then by calling it again its set correctly in y.
			setWindowPosition(windowNo, xpos, ypos);
            setWindowShape(windowNo, screenSize.x, screenSize.y);
			setWindowPosition(windowNo, xpos, ypos);
		}else{
            //for OS X we need to set this first as the window size affects the window positon
            setWindowShape(windowNo, screenSize.x, screenSize.y);
			setWindowPosition(windowNo, 0,0);
		}

        //make sure the window is getting the mouse/key events
        [cocoaWindow makeFirstResponder:cocoaWindow.contentView];

	}else if( windows[windowNo]->bFullscreen == false  ){
        SetSystemUIMode(kUIModeNormal,NULL);

		NSWindow * cocoaWindow = glfwGetCocoaWindow(windows[windowNo]->windowPtr);
		[cocoaWindow setStyleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask];

		setWindowShape(windowNo,
                       windows[windowNo]->windowBounds.getWidth(),
                       windows[windowNo]->windowBounds.getHeight());

		//----------------------------------------------------
		// if we have recorded the screen position, put it there
		// if not, better to let the system do it (and put it where it wants)
		if (ofGetFrameNum() > 0){
			setWindowPosition(windows[windowNo]->windowBounds.x,
                              windows[windowNo]->windowBounds.y);
		}

		//----------------------------------------------------
        //make sure the window is getting the mouse/key events
        [cocoaWindow makeFirstResponder:cocoaWindow.contentView];
	}
#elif defined(TARGET_WIN32)
    if( windows[windowNo]->bFullscreen){
        ofPoint winPos = getWindowPosition(windowNo);
        ofPoint winSize = getWindowSize(windowNo);

        windows[windowNo]->windowBounds.set(winPos.x, winPos.y,
                                            winSize.x, winSize.y);

		//----------------------------------------------------
		HWND hwnd = glfwGetWin32Window(windows[windowNo]->windowPtr);

		SetWindowLong(hwnd, GWL_EXSTYLE, 0);
  		SetWindowLong(hwnd, GWL_STYLE, WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
  		SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

        float fullscreenW = getScreenSize(windowNo).x;
        float fullscreenH = getScreenSize(windowNo).y;

        int xpos = 0;
        int ypos = 0;

        if( bMultiWindowFullscreen ){

            float totalWidth = 0.0;
            float maxHeight  = 0.0;
            int monitorCount;
            GLFWmonitor** monitors = glfwGetMonitors(&monitorCount);

            //lets find the total width of all the monitors
            //and we'll make the window height the height of the largest monitor.
            for(int i = 0; i < monitorCount; i++){
                const GLFWvidmode * desktopMode = glfwGetVideoMode(monitors[i]);
                totalWidth += desktopMode->width;
                if( i == 0 || desktopMode->height > maxHeight ){
                    maxHeight = desktopMode->height;
                }
            }

            fullscreenW = totalWidth;
            fullscreenH = maxHeight;
        }else{

            int monitorCount;
            GLFWmonitor** monitors = glfwGetMonitors(&monitorCount);
            int windowMonitor = getWindowMonitor(windowNo);
            glfwGetMonitorPos(monitors[windowMonitor], &xpos, &ypos);

        }

        SetWindowPos(hwnd, HWND_TOPMOST, xpos, ypos, fullscreenW, fullscreenH, SWP_SHOWWINDOW);

	}else if( windows[windowNo]->bFullscreen == false ){

		HWND hwnd = glfwGetWin32Window(windows[windowNo]->windowPtr);

  		DWORD EX_STYLE = WS_EX_OVERLAPPEDWINDOW;
		DWORD STYLE = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;

	  	ChangeDisplaySettings(0, 0);
		SetWindowLong(hwnd, GWL_EXSTYLE, EX_STYLE);
		SetWindowLong(hwnd, GWL_STYLE, STYLE);
  		SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

		//not sure why this is - but if we don't do this the window shrinks by 4 pixels in x and y
		//should look for a better fix.
		setWindowPosition(windows[windowNo]->windowBounds.x-2,
                          windows[windowNo]->windowBounds.y-2);
		setWindowShape(windows[windowNo]->windowBounds.getWidth()+4,
                       windows[windowNo]->windowBounds.getHeight()+4);
	}
#endif

    if( fullscreen == false && windows[windowNo]->windowName.length() ){
        setWindowTitle(windowNo, windows[windowNo]->windowName);
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setFullscreen(bool fullscreen) {
    setFullscreen(currentWindow, fullscreen);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::toggleFullscreen(int windowNo){
    if (ofInRange(windowNo, 0, windows.size())) {
        if(windows[windowNo]->bFullscreen == false){
            setFullscreen(windowNo, true);
        } else {
            setFullscreen(windowNo, false);
        }
    } else {
        ofLogError("ofxAppGLFWWindowMulti::setFullScreen")
            << "window doesn't exist with windowNo: " << windowNo;
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::toggleFullscreen(){
    toggleFullscreen(currentWindow);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setOrientation(ofOrientation orientation){
	this->orientation = orientation;
}

//------------------------------------------------------------
ofOrientation ofxAppGLFWWindowMulti::getOrientation(){
	return orientation;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::exitApp(){
	ofLogVerbose("ofxAppGLFWWindowMulti") << "terminating GLFW app!";

	// Terminate GLFW
	glfwTerminate();

	OF_EXIT_APP(0);
}

//------------------------------------------------------------
static void rotateMouseXY(ofOrientation orientation, double &x, double &y) {
	int savedY;
	switch(orientation) {
		case OF_ORIENTATION_180:
			x = ofGetWidth() - x;
			y = ofGetHeight() - y;
			break;

		case OF_ORIENTATION_90_RIGHT:
			savedY = y;
			y = x;
			x = ofGetWidth()-savedY;
			break;

		case OF_ORIENTATION_90_LEFT:
			savedY = y;
			y = ofGetHeight() - x;
			x = savedY;
			break;

		case OF_ORIENTATION_DEFAULT:
		default:
			break;
	}
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::mouse_cb(GLFWwindow* windowP_, int button, int state, int mods) {
    instance->setFocusedWindow(windowP_);

	ofLogVerbose("ofxAppGLFWWindowMulti") << "mouse button: " << button;

#ifdef TARGET_OSX
    //we do this as unlike glut, glfw doesn't report right click for ctrl click or middle click for alt click
    if( ofGetKeyPressed(OF_KEY_CONTROL) && button == GLFW_MOUSE_BUTTON_LEFT){
        button = GLFW_MOUSE_BUTTON_RIGHT;
    }
    if( ofGetKeyPressed(OF_KEY_ALT) && button == GLFW_MOUSE_BUTTON_LEFT){
        button = GLFW_MOUSE_BUTTON_MIDDLE;
    }
#endif

	switch(button){
	case GLFW_MOUSE_BUTTON_LEFT:
		button = OF_MOUSE_BUTTON_LEFT;
		break;
	case GLFW_MOUSE_BUTTON_RIGHT:
		button = OF_MOUSE_BUTTON_RIGHT;
		break;
	case GLFW_MOUSE_BUTTON_MIDDLE:
		button = OF_MOUSE_BUTTON_MIDDLE;
		break;
	}

    ofPoint mousePt = instance->windows[instance->focusedWindow]->mousePt;

	if (state == GLFW_PRESS){
        if( instance->focusedWindow == 0 ){
            ofNotifyMousePressed(mousePt.x, mousePt.y, button);
        }else{
            ofAppPtr->mousePressed(mousePt.x, mousePt.y, button);
        }
		instance->buttonPressed=true;
	} else if (state == GLFW_RELEASE) {
        if( instance->focusedWindow == 0 ){
            ofNotifyMouseReleased(mousePt.x, mousePt.y, button);
        }else{
            ofAppPtr->mouseReleased(mousePt.x, mousePt.y, button);
        }
		instance->buttonPressed=false;
	}
	instance->buttonInUse = button;


}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::motion_cb(GLFWwindow* windowP_, double x, double y) {
    // TODO in theory this shouldn't be necessary, but when a new window is
    // created programatically (including via loading settings) callbacks are
    // fired for multiple windows until window 0 is selected
    if (!glfwGetWindowAttrib(windowP_, GLFW_FOCUSED)){
        return;
    }

	rotateMouseXY(ofGetOrientation(), x, y);

    instance->windows[instance->focusedWindow]->mousePt.set(x, y);

    if(!instance->buttonPressed){
        ofNotifyMouseMoved(x, y);
    }else{
        ofNotifyMouseDragged(x, y, instance->buttonInUse);
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::scroll_cb(GLFWwindow* windowP_, double x, double y) {
	// ofSendMessage("scroll|"+ofToString(x,5) + "|" + ofToString(y,5));
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::drop_cb(GLFWwindow* windowP_, int numFiles, const char** dropString) {
    instance->setFocusedWindow(windowP_);

	ofDragInfo drag;
	drag.position.set(ofGetMouseX(), ofGetMouseY());
	drag.files.resize(numFiles);
	for(int i=0; i<(int)drag.files.size(); i++){
		drag.files[i] = Poco::URI(dropString[i]).getPath();
	}
	ofNotifyDragEvent(drag);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::focus_cb(GLFWwindow* windowP_, int focus){
    instance->setFocusedWindow(windowP_);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setFocusedWindow(GLFWwindow * windowP_){
    for(int i = 0; i < windows.size(); i++){
        if( windows[i]->windowPtr && windows[i]->windowPtr == windowP_ ){
            focusedWindow = windows[i]->windowNo;
        }
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::keyboard_cb(GLFWwindow* windowP_, int keycode, int scancode, unsigned int codepoint, int action, int mods) {

        int key;



	switch (keycode){
		case GLFW_KEY_ESCAPE:
			key = OF_KEY_ESC;
			break;
		case GLFW_KEY_F1:
			key = OF_KEY_F1;
			break;
		case GLFW_KEY_F2:
			key = OF_KEY_F2;
			break;
		case GLFW_KEY_F3:
			key = OF_KEY_F3;
			break;
		case GLFW_KEY_F4:
			key = OF_KEY_F4;
			break;
		case GLFW_KEY_F5:
			key = OF_KEY_F5;
			break;
		case GLFW_KEY_F6:
			key = OF_KEY_F6;
			break;
		case GLFW_KEY_F7:
			key = OF_KEY_F7;
			break;
		case GLFW_KEY_F8:
			key = OF_KEY_F8;
			break;
		case GLFW_KEY_F9:
			key = OF_KEY_F9;
			break;
		case GLFW_KEY_F10:
			key = OF_KEY_F10;
			break;
		case GLFW_KEY_F11:
			key = OF_KEY_F11;
			break;
		case GLFW_KEY_F12:
			key = OF_KEY_F12;
			break;
		case GLFW_KEY_LEFT:
			key = OF_KEY_LEFT;
			break;
		case GLFW_KEY_RIGHT:
			key = OF_KEY_RIGHT;
			break;
		case GLFW_KEY_UP:
			key = OF_KEY_UP;
			break;
		case GLFW_KEY_DOWN:
			key = OF_KEY_DOWN;
			break;
		case GLFW_KEY_PAGE_UP:
			key = OF_KEY_PAGE_UP;
			break;
		case GLFW_KEY_PAGE_DOWN:
			key = OF_KEY_PAGE_DOWN;
			break;
		case GLFW_KEY_HOME:
			key = OF_KEY_HOME;
			break;
		case GLFW_KEY_END:
			key = OF_KEY_END;
			break;
		case GLFW_KEY_INSERT:
			key = OF_KEY_INSERT;
			break;
		case GLFW_KEY_LEFT_SHIFT:
			key = OF_KEY_LEFT_SHIFT;
			break;
		case GLFW_KEY_LEFT_CONTROL:
			key = OF_KEY_LEFT_CONTROL;
			break;
		case GLFW_KEY_LEFT_ALT:
			key = OF_KEY_LEFT_ALT;
			break;
		case GLFW_KEY_LEFT_SUPER:
			key = OF_KEY_LEFT_SUPER;
			break;
		case GLFW_KEY_RIGHT_SHIFT:
			key = OF_KEY_RIGHT_SHIFT;
			break;
		case GLFW_KEY_RIGHT_CONTROL:
			key = OF_KEY_RIGHT_CONTROL;
			break;
		case GLFW_KEY_RIGHT_ALT:
			key = OF_KEY_RIGHT_ALT;
			break;
		case GLFW_KEY_RIGHT_SUPER:
			key = OF_KEY_RIGHT_SUPER;
            break;
		case GLFW_KEY_BACKSPACE:
			key = OF_KEY_BACKSPACE;
			break;
		case GLFW_KEY_DELETE:
			key = OF_KEY_DEL;
			break;
		case GLFW_KEY_ENTER:
			key = OF_KEY_RETURN;
			break;
		case GLFW_KEY_KP_ENTER:
			key = OF_KEY_RETURN;
			break;
		case GLFW_KEY_TAB:
			key = OF_KEY_TAB;
			break;
		default:
			key = codepoint;
			break;
	}

    if(action == GLFW_PRESS || action == GLFW_REPEAT){
		ofNotifyKeyPressed(key,keycode,scancode,codepoint);
    }else if (action == GLFW_RELEASE){
		ofNotifyKeyReleased(key,keycode,scancode,codepoint);
    }
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::resize_cb(GLFWwindow* windowP_,int w, int h) {
    instance->setFocusedWindow(windowP_);
    instance->updateWindowSize(instance->getFocusedWindowNo());
    ofNotifyWindowResized(w, h);
	instance->nFramesSinceWindowResized = 0;
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::setVerticalSync(bool bVerticalSync){
	if(bVerticalSync){
		glfwSwapInterval( 1);
	}else{
		glfwSwapInterval(0);
	}
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::listVideoModes(){
	int numModes;
	const GLFWvidmode * vidModes = glfwGetVideoModes(NULL, &numModes );
	for(int i=0; i<numModes; i++){
		ofLogNotice() << vidModes[i].width << " x " << vidModes[i].height
		<< vidModes[i].redBits+vidModes[i].greenBits+vidModes[i].blueBits << "bit";
	}
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::isWindowIconified(){
	return glfwGetWindowAttrib(windows[currentWindow]->windowPtr, GLFW_ICONIFIED);
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::isWindowActive(){
//	return glfwGetWindowParam(GLFW_ACTIVE);
	return true;
}

//------------------------------------------------------------
bool ofxAppGLFWWindowMulti::isWindowResizeable(){
	return !glfwGetWindowAttrib(windows[currentWindow]->windowPtr, GLFW_RESIZABLE);
}

//------------------------------------------------------------
void ofxAppGLFWWindowMulti::iconify(bool bIconify){
	if(bIconify)
			glfwIconifyWindow(windows[currentWindow]->windowPtr);
	else
		glfwRestoreWindow(windows[currentWindow]->windowPtr);
}


#if defined(TARGET_LINUX) && !defined(TARGET_RASPBERRY_PI)
Display* ofxAppGLFWWindowMulti::getX11Display(){
	return glfwGetX11Display();
}

Window ofxAppGLFWWindowMulti::getX11Window(){
	return glfwGetX11Window(windows[currentWindow]->windowPtr);
}
#endif

#if defined(TARGET_LINUX) && !defined(TARGET_OPENGLES)
GLXContext ofxAppGLFWWindowMulti::getGLXContext(){
	return glfwGetGLXContext(windows[currentWindow]->windowPtr);
}
#endif

#if defined(TARGET_LINUX) && defined(TARGET_OPENGLES)
EGLDisplay ofxAppGLFWWindowMulti::getEGLDisplay(){
	return glfwGetEGLDisplay();
}

EGLContext ofxAppGLFWWindowMulti::getEGLContext(){
	return glfwGetEGLContext(windows[currentWindow]->windowPtr);
}

EGLSurface ofxAppGLFWWindowMulti::getEGLSurface(){
	return glfwGetEGLSurface(windows[currentWindow]->windowPtr);
}
#endif

#if defined(TARGET_OSX)
void * ofxAppGLFWWindowMulti::getNSGLContext(){
	return glfwGetNSGLContext(windows[currentWindow]->windowPtr);
}

void * ofxAppGLFWWindowMulti::getCocoaWindow(){
	return glfwGetCocoaWindow(windows[currentWindow]->windowPtr);
}
#endif

#if defined(TARGET_WIN32)
HGLRC ofxAppGLFWWindowMulti::getWGLContext(){
	return glfwGetWGLContext(windows[currentWindow]->windowPtr);
}

HWND ofxAppGLFWWindowMulti::getWin32Window(){
	return glfwGetWin32Window(windows[currentWindow]->windowPtr);
}

#endif
