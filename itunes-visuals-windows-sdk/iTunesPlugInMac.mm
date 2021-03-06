//
// File:       iTunesPlugInMac.mm
//
// Abstract:   Visual plug-in for iTunes on MacOS
//
// Version:    2.0
//
// Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc. ( "Apple" )
//             in consideration of your agreement to the following terms, and your use,
//             installation, modification or redistribution of this Apple software
//             constitutes acceptance of these terms.  If you do not agree with these
//             terms, please do not use, install, modify or redistribute this Apple
//             software.
//
//             In consideration of your agreement to abide by the following terms, and
//             subject to these terms, Apple grants you a personal, non - exclusive
//             license, under Apple's copyrights in this original Apple software ( the
//             "Apple Software" ), to use, reproduce, modify and redistribute the Apple
//             Software, with or without modifications, in source and / or binary forms;
//             provided that if you redistribute the Apple Software in its entirety and
//             without modifications, you must retain this notice and the following text
//             and disclaimers in all such redistributions of the Apple Software. Neither
//             the name, trademarks, service marks or logos of Apple Inc. may be used to
//             endorse or promote products derived from the Apple Software without specific
//             prior written permission from Apple.  Except as expressly stated in this
//             notice, no other rights or licenses, express or implied, are granted by
//             Apple herein, including but not limited to any patent rights that may be
//             infringed by your derivative works or by other works in which the Apple
//             Software may be incorporated.
//
//             The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
//             WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
//             WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
//             PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION
//             ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//
//             IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
//             CONSEQUENTIAL DAMAGES ( INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//             SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//             INTERRUPTION ) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
//             AND / OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER
//             UNDER THEORY OF CONTRACT, TORT ( INCLUDING NEGLIGENCE ), STRICT LIABILITY OR
//             OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Copyright © 2001-2011 Apple Inc. All Rights Reserved.
//

//-------------------------------------------------------------------------------------------------
//	includes
//-------------------------------------------------------------------------------------------------

#import "iTunesPlugIn.h"

#import <AppKit/AppKit.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <string.h>

//-------------------------------------------------------------------------------------------------
//	constants, etc.
//-------------------------------------------------------------------------------------------------

#define kTVisualPluginName              CFSTR("iTunes Sample Visualizer")

//-------------------------------------------------------------------------------------------------
//	exported function prototypes
//-------------------------------------------------------------------------------------------------

extern "C" OSStatus iTunesPluginMainMachO( OSType inMessage, PluginMessageInfo *inMessageInfoPtr, void *refCon ) __attribute__((visibility("default")));

#if USE_SUBVIEW
//-------------------------------------------------------------------------------------------------
//	VisualView
//-------------------------------------------------------------------------------------------------

@interface VisualView : NSView
{
	VisualPluginData *	_visualPluginData;
}

@property (nonatomic, assign) VisualPluginData * visualPluginData;

-(void)drawRect:(NSRect)dirtyRect;
- (BOOL)acceptsFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
-(void)keyDown:(NSEvent *)theEvent;

@end

#endif	// USE_SUBVIEW

//-------------------------------------------------------------------------------------------------
//	DrawVisual
//-------------------------------------------------------------------------------------------------
//
void DrawVisual( VisualPluginData * visualPluginData )
{
	CGRect			drawRect;
	CGPoint			where;

	// this shouldn't happen but let's be safe
	if ( visualPluginData->destView == NULL )
		return;

	drawRect = [visualPluginData->destView bounds];

	// fill the whole view with black to start
	[[NSColor blackColor] set];
	NSRectFill( drawRect );

	// pick a random location to draw our little square
	double			randomX = (random() / 2147483647.0);		// [0, 1]
	double			randomY = (random() / 2147483647.0);		// [0, 1]

	where.x = (CGFloat)(randomX * drawRect.size.width);
	where.y = (CGFloat)(randomY * drawRect.size.height);

	if ( visualPluginData->playing )
	{
		// if playing, draw a square whose color is dictated by the current max levels
		CGFloat		red		= (CGFloat)visualPluginData->maxLevel[1] / 256.0;
		CGFloat		green	= (CGFloat)visualPluginData->maxLevel[1] / 256.0;
		CGFloat		blue	= (CGFloat)visualPluginData->maxLevel[0] / 256.0;

		[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:1] set];
	}
	else
	{
		// if idle, draw a partially transparent blue square
		[[[NSColor blueColor] colorWithAlphaComponent:0.75] set];
	}

	drawRect = NSMakeRect( where.x, where.y, 100, 100 );

	NSRectFill( drawRect );

	// should we draw the info/artwork in the bottom-left corner?
	time_t		theTime = time( NULL );

	if ( theTime < visualPluginData->drawInfoTimeOut )
	{
		where = CGPointMake( 10, 10 );

		// if we have a song title, draw it (prefer the stream title over the regular name if we have it)
		NSString *				theString = NULL;

		if ( visualPluginData->streamInfo.streamTitle[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->streamInfo.streamTitle[1] length:visualPluginData->streamInfo.streamTitle[0]];
		else if ( visualPluginData->trackInfo.name[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->trackInfo.name[1] length:visualPluginData->trackInfo.name[0]];
		
		if ( theString != NULL )
		{
			NSDictionary *		attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, NULL];
			
			[theString drawAtPoint:where withAttributes:attrs];
		}

		// draw the artwork
		if ( visualPluginData->currentArtwork != NULL )
		{
			where.y += 20;

			[visualPluginData->currentArtwork drawAtPoint:where fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.75];
		}
	}
}

//-------------------------------------------------------------------------------------------------
//	UpdateArtwork
//-------------------------------------------------------------------------------------------------
//
void UpdateArtwork( VisualPluginData * visualPluginData, CFDataRef coverArt, UInt32 coverArtSize, UInt32 coverArtFormat )
{
	// release current image
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
	
	// create 100x100 NSImage* out of incoming CFDataRef if non-null (null indicates there is no artwork for the current track)
	if ( coverArt != NULL )
	{
		visualPluginData->currentArtwork = [[NSImage alloc] initWithData:(NSData *)coverArt];
		
		[visualPluginData->currentArtwork setSize:CGSizeMake( 100, 100 )];
	}
	
	UpdateInfoTimeOut( visualPluginData );
}

//-------------------------------------------------------------------------------------------------
//	InvalidateVisual
//-------------------------------------------------------------------------------------------------
//
void InvalidateVisual( VisualPluginData * visualPluginData )
{
	(void) visualPluginData;

#if USE_SUBVIEW
	// when using a custom subview, we invalidate it so we get our own draw calls
	[visualPluginData->subview setNeedsDisplay:YES];
#endif
}

//-------------------------------------------------------------------------------------------------
//	CreateVisualContext
//-------------------------------------------------------------------------------------------------
//
OSStatus ActivateVisual( VisualPluginData * visualPluginData, VISUAL_PLATFORM_VIEW destView, OptionBits options )
{
	OSStatus			status = noErr;

	visualPluginData->destView			= destView;
	visualPluginData->destRect			= [destView bounds];
	visualPluginData->destOptions		= options;

	UpdateInfoTimeOut( visualPluginData );

#if USE_SUBVIEW

	// NSView-based subview
	visualPluginData->subview = [[VisualView alloc] initWithFrame:visualPluginData->destRect];
	if ( visualPluginData->subview != NULL )
	{
		[visualPluginData->subview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

		[visualPluginData->subview setVisualPluginData:visualPluginData];

		[destView addSubview:visualPluginData->subview];
	}
	else
	{
		status = memFullErr;
	}

#endif

	return status;
}

//-------------------------------------------------------------------------------------------------
//	MoveVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus MoveVisual( VisualPluginData * visualPluginData, OptionBits newOptions )
{
	visualPluginData->destRect	  = [visualPluginData->destView bounds];
	visualPluginData->destOptions = newOptions;

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	DeactivateVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus DeactivateVisual( VisualPluginData * visualPluginData )
{
#if USE_SUBVIEW
	[visualPluginData->subview removeFromSuperview];
	[visualPluginData->subview autorelease];
	visualPluginData->subview = NULL;
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
#endif

	visualPluginData->destView			= NULL;
	visualPluginData->destRect			= CGRectNull;
	visualPluginData->drawInfoTimeOut	= 0;
	
	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ResizeVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ResizeVisual( VisualPluginData * visualPluginData )
{
	visualPluginData->destRect = [visualPluginData->destView bounds];

	// note: the subview is automatically resized by iTunes so nothing to do here

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ConfigureVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ConfigureVisual( VisualPluginData * visualPluginData )
{
	(void) visualPluginData;

	// load nib
	// show modal dialog
	// update settings
	// invalidate

	return noErr;
}

#pragma mark -

#if USE_SUBVIEW

@implementation VisualView

@synthesize visualPluginData = _visualPluginData;

//-------------------------------------------------------------------------------------------------
//	isOpaque
//-------------------------------------------------------------------------------------------------
//
- (BOOL)isOpaque
{
	// your custom views should always be opaque or iTunes will waste CPU time drawing behind you
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	drawRect
//-------------------------------------------------------------------------------------------------
//
-(void)drawRect:(NSRect)dirtyRect
{
	if ( _visualPluginData != NULL )
	{
		DrawVisual( _visualPluginData );
	}
}

//-------------------------------------------------------------------------------------------------
//	acceptsFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)acceptsFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	becomeFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)becomeFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	resignFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)resignFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	keyDown
//-------------------------------------------------------------------------------------------------
//
-(void)keyDown:(NSEvent *)theEvent
{
	// Handle key events here.
	// Do not eat the space bar, ESC key, TAB key, or the arrow keys: iTunes reserves those keys.

	// if the 'i' key is pressed, reset the info timeout so that we draw it again
	if ( [[theEvent charactersIgnoringModifiers] isEqualTo:@"i"] )
	{
		UpdateInfoTimeOut( _visualPluginData );
		return;
	}

	// Pass all unhandled events up to super so that iTunes can handle them.
	[super keyDown:theEvent];
}

@end

#endif	// USE_SUBVIEW

#pragma mark -

//-------------------------------------------------------------------------------------------------
//	GetVisualName
//-------------------------------------------------------------------------------------------------
//
void GetVisualName( ITUniStr255 name )
{
	CFIndex length = CFStringGetLength( kTVisualPluginName );

	name[0] = (UniChar)length;
	CFStringGetCharacters( kTVisualPluginName, CFRangeMake( 0, length ), &name[1] );
}

//-------------------------------------------------------------------------------------------------
//	GetVisualOptions
//-------------------------------------------------------------------------------------------------
//
OptionBits GetVisualOptions( void )
{
	OptionBits		options = (kVisualSupportsMuxedGraphics | kVisualWantsIdleMessages | kVisualWantsConfigure);
	
#if USE_SUBVIEW
	options |= kVisualUsesSubview;
#endif

	return options;
}

//-------------------------------------------------------------------------------------------------
//	iTunesPluginMainMachO
//-------------------------------------------------------------------------------------------------
//
OSStatus iTunesPluginMainMachO( OSType message, PluginMessageInfo * messageInfo, void * refCon )
{
	OSStatus		status;
	
	(void) refCon;
	
	switch ( message )
	{
		case kPluginInitMessage:
			status = RegisterVisualPlugin( messageInfo );
			break;
			
		case kPluginCleanupMessage:
			status = noErr;
			break;
			
		default:
			status = unimpErr;
			break;
	}
	
	return status;
}