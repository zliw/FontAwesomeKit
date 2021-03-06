class CodeGenerator
  attr_accessor :font_name, :names, :codes

  def initialize(font_name, names, codes, names_are_camel_case:true, prefix:'')
    @font_name = font_name

    if names_are_camel_case
      @camel_case_names = names
    else
      # create a capitalized version of strings
      @camel_case_names = names.map do |name|
        name = self.string_to_camel_case(name)
      end
    end

    @prefix = prefix

    # names get mangled to avoid non-ascii characters
    @names = names.map do |name|
      name.gsub(/[^0-9a-z\-]/i, '')
    end

    uppercase_prefix = prefix.capitalize.gsub('-', '')
    @symbols = @camel_case_names.map do |name|
      ucfirst = name.clone;
      ucfirst[0] = ucfirst[0,1].upcase 
      'FAKGlyph' + uppercase_prefix + ucfirst
    end

    @codes = codes

    if names.length != codes.length
      raise 'names array should be same length as codes array'
    end

    @class_name = "FAK#{@font_name}"
    @header_file = "#{@class_name}.h"
    @header_file_gen = "#{@class_name}.fakgen.h"
    @implementation_file = "#{@class_name}.fakgen.m"

  end

  def generate
    File.open(@header_file_gen, 'w+') { |f| f.write(generate_header) }
    File.open(@implementation_file, 'w+') { |f| f.write(generate_implementation) }
  end

  # takes a string like 'fa-bar' and creates a camelCase notation like 'faBar'
  def string_to_camel_case(string)
    stringParts = string.split('-')
    stringParts = stringParts.each_with_index.map do |p, i|
       if i < 1
         p
       else
         p = p.capitalize
       end
     end

    return stringParts.join
  end

  # takes a string like 'bar' and creates a uppercase notation suitable for defines like 'FA_BAR'
  def string_to_upper_case(string)
    return @prefix.capitalize.gsub('-', '_')  + string.capitalize.gsub('-', '_')
  end

  def generate_header
    header = "// This file is generated - Do no edit\n\n"
    header = header << '#import "FAKIcon.h"'
    header = header << "\n\n@interface #{@class_name}:FAKIcon"
    header = header << "\n\n#pragma mark Generated method signatures\n"

    @camel_case_names.each do |name|
      header_template = <<EOT
+ (instancetype)#{name}IconWithSize:(CGFloat)size;
EOT
      header << header_template;
    end

    header = header << "\n\n+ (NSDictionary *)allNames;\n\n@end\n"

    return header
  end

  def generate_implementation

    implementation = <<EOT
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "#{@header_file}"

EOT
    implementation = implementation << generate_symbols

    signature = <<EOT
@implementation FAKFontAwesome

+ (UIFont *)iconFontWithSize:(CGFloat)size
{
#ifndef DISABLE_FONTAWESOME_AUTO_REGISTRATION
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerIconFontWithURL:[[NSBundle mainBundle] URLForResource:@"#{@font_name}" withExtension:@"otf"]];
    });
#endif

    UIFont *font = [UIFont fontWithName:@"#{@font_name}" size:size];
    NSAssert(font, @"UIFont object should not be nil, check if the font file is added to the application bundle and you're using the correct font name.");
    return font;
}

EOT

    implementation = implementation << signature 
    implementation << "\n#pragma mark Generated class method for constructing icon methods\n// Do no edit\n\n"

    @camel_case_names.each_with_index do |name, index|
      implementation_template = <<EOT
+ (instancetype)#{name}IconWithSize:(CGFloat)size { return [self iconWithCode:#{@symbols[index]} size:size]; }
EOT
      implementation << implementation_template
    end

    return implementation + "\n" + generate_icon_map + "\n" + generate_name_map + "\n@end\n"
  end

  def generate_symbols
    symbols = "#pragma mark Symbol definitions\n\n"

    @symbols.each_with_index do |symbol, index|
      symbol_template = <<EOT
static NSString *const #{symbol} = @"#{@codes[index]}";
EOT
      symbols << symbol_template
    end

    return symbols << "\n"
  end

  def generate_icon_map
    icon_map = ''
    @camel_case_names.each_with_index do |name, index|
      icon_map_template = <<EOT 
      #{@symbols[index]} : @"#{name}",
EOT
      icon_map << icon_map_template
    end

    icon_map = <<EOT
#pragma mark - Generated mapping methods
// Do not edit

/** method for providing a mapping of all unicode characters being assigned a name -
 note: duplicate keys may lead to alias names colliding with primary names.
 @return a NSDictionary containing unicode characters as keys and transformed names as values. names
 have been stripped of prefixes and are converted to camelCase to maintain compability.
*/
+ (NSDictionary *)allIcons {
    return @{
#{icon_map}
    };
}
EOT
  end

  def generate_name_map
    name_map = ''
    @names.each_with_index do |name, index|
      name_map_template = <<EOT
      @"#{@prefix}#{name}" : #{@symbols[index]},
EOT
      name_map << name_map_template
    end

    return <<EOT
/** method for providing a mapping of names as given by the font
 creator to the unicode character sequence producing the icon
    @return a NSDictionary. The keys are the names, the values are the unicode character sequences
  */
+ (NSDictionary *)allNames {
    return @{
#{name_map}
    };
}
EOT
  end

end
