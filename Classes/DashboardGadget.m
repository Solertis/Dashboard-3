//
//  DashboardGadget.m
//  Dashboard
//
//  Copyright (c) 2010 Rich Hong
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "DashboardGadget.h"


@implementation DashboardGadget

@synthesize title, url, height, width, prefHtml, parsingEnum, screenshot, thumbnail;

- (DashboardGadget*) initWithUrl:(NSString*) aUrl {
    if ((self = [super init])) {
        // Default settings
        self.height = 100;
        self.width = 300;
        NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"preference_opensocial_server"];
        self.url = [[server stringByAppendingString:@"/gadgets/ifr?url="] stringByAppendingString: aUrl];
        self.prefHtml = [NSString string];
        self.screenshot = nil;
        self.thumbnail = nil;
        self.parsingEnum = NO;
    }
    return self;
}

/*!
 * Create .wdgt directory for a google gadget
 * @result Full name of the .wdgt directory created.
 */
- (NSString*) createWidget {
    NSString *widgetPath = [DashboardAppDelegate widgetPath];
    NSString *path = [self.title stringByAppendingString:@".wdgt"];
    NSString *widgetDir = [widgetPath stringByAppendingPathComponent:path];
    // Create widget directory
    [[NSFileManager defaultManager] createDirectoryAtPath:widgetDir withIntermediateDirectories:YES attributes:nil error:NULL];

    // Download screenshot and thumbnail as Default.png and Icon.png or use empty icon as backup
    NSString *emptyIconPath = [[NSBundle mainBundle] pathForResource:@"DashboardIcon" ofType:@"png"];
    NSString *screenshotPath = [widgetDir stringByAppendingPathComponent:@"Default.png"];
    if (self.screenshot) {
        NSURLResponse *response = nil;
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.screenshot]];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
        [data writeToFile:screenshotPath atomically:NO];
    } else {
        [[NSFileManager defaultManager] copyItemAtPath:emptyIconPath toPath:screenshotPath error:NULL];
    }
    NSString *thumbnailPath = [widgetDir stringByAppendingPathComponent:@"Icon.png"];
    if (self.thumbnail) {
        NSURLResponse *response = nil;
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.thumbnail]];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
        [data writeToFile:thumbnailPath atomically:NO];
    } else {
        [[NSFileManager defaultManager] copyItemAtPath:emptyIconPath toPath:thumbnailPath error:NULL];
    }

    // Create Info.plist
    NSMutableDictionary* plist = [NSMutableDictionary dictionary];
    [plist setValue:[NSNumber numberWithBool:YES] forKey:@"AllowFullAccess"];
    [plist setValue:self.title forKey:@"CFBundleDisplayName"];
    [plist setValue:self.title forKey:@"CFBundleName"];
    [plist setValue:[@"com.gadget." stringByAppendingString:[self.title stringByReplacingOccurrencesOfString:@" " withString:@""]] forKey:@"CFBundleIdentifier"];
    [plist setValue:@"gadget.html" forKey:@"MainHTML"];
    // TODO: Figure out width somehow
    [plist setValue:[NSNumber numberWithInt:(self.width + GADGET_PADDING)] forKey:@"Width"];
    [plist setValue:[NSNumber numberWithInt:(self.height + GADGET_PADDING)] forKey:@"Height"];
    [plist setValue:[NSNumber numberWithInt:15] forKey:@"CloseBoxInsetX"];
    [plist setValue:[NSNumber numberWithInt:15] forKey:@"CloseBoxInsetY"];
    [plist writeToFile:[widgetDir stringByAppendingPathComponent:@"Info.plist"] atomically:NO];
    // Copy over gadget.html
    [[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"gadget" ofType:@"html"] toPath:[widgetDir stringByAppendingPathComponent:@"gadget.html"] error:NULL];

    NSStringEncoding enc;
    NSString *file = [NSString stringWithContentsOfFile:[widgetDir stringByAppendingPathComponent:@"gadget.html"] usedEncoding:&enc error:NULL];
    // Change iframe src
    file = [file stringByReplacingOccurrencesOfString:@"src=\"inner.html\"" withString:[NSString stringWithFormat:@"src=\"%@\"", self.url]];
    // Change dimension
    file = [file stringByReplacingOccurrencesOfString:@"var frontWidth = 250;" withString:[NSString stringWithFormat:@"var frontWidth = %d;", self.width]];
    file = [file stringByReplacingOccurrencesOfString:@"var frontHeight = 70;" withString:[NSString stringWithFormat:@"var frontHeight = %d;", self.height]];
    // Add more UserPrefs
    file = [file stringByReplacingOccurrencesOfString:@"<!-- UserPref Section -->" withString:self.prefHtml];

    [file writeToFile:[widgetDir stringByAppendingPathComponent:@"gadget.html"] atomically:NO encoding:enc error:NULL];
    return path;
}

#pragma mark -
#pragma mark NSXMLParserDelegate Protocol

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {

    if ([elementName isEqualToString:@"ModulePrefs"]) {
        self.title = [attributeDict valueForKey:@"title"];
        if ([attributeDict objectForKey:@"directory_title"] != nil) {
            self.title = [attributeDict valueForKey:@"directory_title"];
        }
        if ([attributeDict objectForKey:@"height"] != nil) {
            self.height = [[attributeDict valueForKey:@"height"] intValue];
        }
        if ([attributeDict objectForKey:@"width"] != nil) {
            self.width = [[attributeDict valueForKey:@"width"] intValue];
        }
        if ([attributeDict objectForKey:@"screenshot"] != nil) {
            self.screenshot = [attributeDict valueForKey:@"screenshot"];
        }
        if ([attributeDict objectForKey:@"thumbnail"] != nil) {
            self.thumbnail = [attributeDict valueForKey:@"thumbnail"];
        }
    } else if ([elementName isEqualToString:@"UserPref"]) {
        NSString *name = [attributeDict valueForKey:@"name"];
        NSString *datatype = [attributeDict valueForKey:@"datatype"];
        NSString *display_name = name;
        if ([attributeDict objectForKey:@"display_name"] != nil) {
            display_name = [attributeDict objectForKey:@"display_name"];
        }
        NSString *urlparam = name;
        if ([attributeDict objectForKey:@"urlparam"] != nil) {
            urlparam = [attributeDict objectForKey:@"urlparam"];
        }
        NSString *default_value = @"";
        if ([attributeDict objectForKey:@"default_value"] != nil) {
            default_value = [attributeDict objectForKey:@"default_value"];
        }
        // TODO: support 'required'

        if (![datatype isEqualToString:@"hidden"]) {
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<label for='UserPref_%@'>%@</label>", name, display_name];
        }
        // TODO: support list type
        // datatype defaults to string if not specified
        if (datatype == nil || [datatype isEqualToString:@"string"]) {
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<input id='UserPref_%@' urlparam='%@' value='%@' type='text' size='17'>", name, urlparam, default_value];
        } else if ([datatype isEqualToString:@"enum"]) {
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<select id='UserPref_%@' urlparam='%@' value='%@'>", name, urlparam, default_value];
            self.parsingEnum = YES;
        } else if ([datatype isEqualToString:@"hidden"]) {
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<input id='UserPref_%@' urlparam='%@' value='%@' type='hidden'>", name, urlparam, default_value];
        } else if ([datatype isEqualToString:@"bool"]) {
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<span id='UserPref_%@' urlparam='%@'>", name, urlparam];
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<input id='UserPref_%@_true' type='radio' name='UserPref_%@' value='true'", name, name];
            if ([default_value isEqualToString:@"true"]) {
                self.prefHtml = [self.prefHtml stringByAppendingString:@"checked"];
            }
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"><label for='UserPref_%@_true'>True</label>", name];
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<input id='UserPref_%@_false' type='radio' name='UserPref_%@' value='false'", name, name];
            if ([default_value isEqualToString:@"false"]) {
                self.prefHtml = [self.prefHtml stringByAppendingString:@"checked"];
            }
            self.prefHtml = [self.prefHtml stringByAppendingFormat:@"><label for='UserPref_%@_false'>False</label>", name];
            self.prefHtml = [self.prefHtml stringByAppendingString:@"</span>"];
        }
    } else if (self.parsingEnum == YES && [elementName isEqualToString:@"EnumValue"]) {
        NSString *value = [attributeDict valueForKey:@"value"];
        NSString *display_value = value;
        if ([attributeDict objectForKey:@"display_value"] != nil) {
            display_value = [attributeDict objectForKey:@"display_value"];
        }
        self.prefHtml = [self.prefHtml stringByAppendingFormat:@"<option value='%@'>%@</option>", value, display_value];
    } else if ([elementName isEqualToString:@"Content"]) {
        NSString *type = [attributeDict valueForKey:@"type"];
        if ([type isEqualToString:@"url"]) {
            self.url = [attributeDict valueForKey:@"href"];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if (self.parsingEnum == YES && [elementName isEqualToString:@"UserPref"]) {
        self.parsingEnum = NO;
        self.prefHtml = [self.prefHtml stringByAppendingString:@"</select>"];
    }
}

- (void) dealloc {
    self.title = nil;
    self.url = nil;
    self.prefHtml = nil;
    self.screenshot = nil;
    self.thumbnail = nil;
    [super dealloc];
}

@end
