//
//  MADXMLSerialization.m
//
//  The MIT License (MIT)
//
//  Copyright (c) 2018 James Madley
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "MADXMLSerialization.h"

@interface NSString (Trimmed)

- (NSString *)stringByTrimmingEmptyCharacters;

@end

@implementation NSString (Trimmed)

- (NSString *)stringByTrimmingEmptyCharacters {
  return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

@interface MADXMLElement : NSObject

@property NSString *name;
@property MADXMLElement *parent;
@property NSMutableDictionary *content;

- (instancetype)initWithName:(NSString *)name parent:(MADXMLElement *)parent;

- (void)addChild:(NSDictionary *)child forElement:(NSString *)element;

@end

@implementation MADXMLElement

- (instancetype)init {
  return [self initWithName:nil parent:nil];
}

- (instancetype)initWithName:(NSString *)name parent:(MADXMLElement *)parent {
  self = [super init];
  if (self) {
    self.name = name;
    self.parent = parent;
    self.content = [NSMutableDictionary new];
  }
  return self;
}

- (void)addChild:(NSDictionary *)child forElement:(NSString *)element {
  id existingChild = [self.content objectForKey:element];
  if (existingChild) {
    if (![existingChild isKindOfClass:[NSArray class]]) {
      existingChild = @[existingChild];
    }
    NSMutableArray *arrayChild = [NSMutableArray arrayWithArray:existingChild];
    [arrayChild addObject:child];
    [self.content setObject:arrayChild forKey:element];
  } else {
    [self.content setObject:child forKey:element];
  }
}

@end

@interface MADXMLDeserializer : NSObject<NSXMLParserDelegate> {
  NSData *xmlData;
  NSError * __autoreleasing *xmlError;
  MADXMLElement *currentElement;
  NSMutableString *temporaryValueCharacters;
}
@end

@implementation MADXMLDeserializer

- (instancetype)initWithData:(NSData *)data error:(NSError * _Nullable *)error {
  self = [super init];
  if (self) {
    xmlData = data;
    xmlError = error;
    currentElement = [[MADXMLElement alloc] init];
    temporaryValueCharacters = [NSMutableString new];
  }
  return self;
}

- (NSDictionary *)deserializedDictionary {
  NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
  parser.delegate = self;
  if ([parser parse]) {
    return currentElement.content;
  }
  return nil;
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary<NSString *, NSString *> *)attributeDict {
  if ([temporaryValueCharacters stringByTrimmingEmptyCharacters].length == 0) {
    // Create new current element dictionary
    currentElement = [[MADXMLElement alloc] initWithName:elementName parent:currentElement];
    
    // Add attribute dictionary to the current element
    if (attributeDict.count > 0) {
      [currentElement addChild:attributeDict forElement:@"_attributes"];
    }
  } else {
    // The starting element is markup
    [temporaryValueCharacters appendFormat:@"<%@>", elementName];
  }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
  [temporaryValueCharacters appendString:string];
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName {
  if ([elementName isEqualToString:currentElement.name]) {
    // Trim the temp characters of newlines at both ends and plain empty strings
    NSString *value = [temporaryValueCharacters stringByTrimmingEmptyCharacters];
    
    // Save the value to this element
    if (value.length > 0) {
      [currentElement.content setObject:value forKey:@"_value"];
    }
    
    // Clear the temp characters
    temporaryValueCharacters = [NSMutableString new];
    
    // Save the child to the parent
    [currentElement.parent addChild:currentElement.content forElement:elementName];
    
    // Move back to the parent
    currentElement = currentElement.parent;
  } else {
    // The ending element is markup
    [temporaryValueCharacters appendFormat:@"</%@>", elementName];
  }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
  *xmlError = parseError;
}

@end

@implementation MADXMLSerialization

+ (NSDictionary *)XMLDictionaryWithData:(NSData *)data error:(NSError * _Nullable *)error {
  MADXMLDeserializer *instance = [[MADXMLDeserializer alloc] initWithData:data error:error];
  return [instance deserializedDictionary];
}

+ (instancetype)alloc {
  @throw [NSException exceptionWithName:NSInvalidArgumentException
                                 reason:@"Do not create instances of MADXMLSerialisation"
                               userInfo:nil];
}

@end
