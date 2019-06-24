# frozen_string_literal: true

require 'rexml/document'

# XMLLens wraps around rexml/document and XPath to provide
# augeas esque-manipulation of an xml file.
class XmlLens
  # Initialized with the file(preloaded), any changes and any conditions
  def initialize(xml, changes = nil, conditions = nil)
    raise ArgumentError unless xml.is_a? REXML::Document
    @xml = xml
    @operations = []
    @validations = []

    # Initialize our ops and validations
    # these get batched and executed en-masse
    unless changes.nil?
      if changes.is_a? Array
        changes.each { |change| parser(change) }
      elsif changes.is_a? String
        parser(changes)
      else
        raise ArgumentError
      end
    end

    unless conditions.nil?
      if conditions.is_a? Array
        conditions.each { |condition| parser(condition) }
      elsif conditions.is_a? String
        parser(conditions)
      end
    end
  end

  # Wrap around XPath.match
  def match(match, xml = @xml)
    REXML::XPath.match(xml, match)
  end

  # Evaluates.  Calls the procs that have been loaded.
  def evaluate
    # First up validations
    @validations.each do |validate|
      next if validate.call
      return @xml
    end
    # Those passed, so next up is actual operations
    @operations.each do |operation|
      operation.call
    end
    @xml
  end

  # Add a blank node
  def add(addto, add)
    start_element = nil
    cur_element = nil
    add.each do |build|
      if cur_element.nil?
        cur_element = REXML::Element.new(build[0])
        start_element = cur_element
      else
        cur_element = cur_element.add_element(build[0])
      end
    end
    addto.first.add_element(start_element)
  end

  # Clears an element
  def clear(path)
    if path.is_a? Array
      path.each do |p|
        p.elements.each do |child|
          p.elements.delete(child)
        end
        p.text = nil
        p.attributes.keys.each do |key|
          p.attributes.delete(key)
        end
      end
    elsif path.is_a? REXML::Element
      path.elements.each do |child|
        path.elements.delete(child)
      end
      path.text = nil
      path.attributes.keys.each do |key|
        path.attributes.delete(key)
      end
    else
      raise ArgumentError
    end
  end

  # Checks if a match has a certain value(attribute or text)
  def get(match, expr, value, attr)
    retval = false
    match.each do |m|
      retval = if attr && !attr.empty?
                 evaluate_expression(m.attributes[attr], expr, value)
               else
                 evaluate_expression(m.text, expr, value)
               end
      break if retval
    end
    retval
  end

  # Deletes a node
  def rm(path)
    if path.is_a? Array
      path.each do |p|
        p.parent.elements.delete(p) if p.parent
      end
    elsif path.is_a? REXML::Element
      path.parent.elements.delete(p) if path.parent
    else
      raise ArgumentError
    end
  end

  # Sets a node or node attribute to a value.  Creates it if it doesn't exist
  def set(element, value, attribute, path)
    if element.nil?
      built_path = build_path(path.scan(/\/([^\[\/]+)(\[[^\]\[]+\])?/))
      if built_path[:exists]
        set_element = built_path[:final_path].first
      else
        set_element = built_path[:final_path].first
        built_path[:remainder].each do |add|
          set_element = set_element.elements.add(add)
        end
      end
    else
      set_element = element.first
    end
    if attribute
      set_element.attributes[attribute] = value
    else
      set_element.text = value
    end
  end

  # Type is ignored for now as I didn't really have a use case for it.
  def sort(element, attr, _type)
    if element.is_a?(Array)
      element.each do |elem|
        case attr
        when 'text'
          sorted = elem.elements.sort_by(&:text)
        when nil, ''
          sorted = elem.elements.sort_by(&:name)
        else
          sorted = elem.elements.sort { |e1, e2| e1.attributes[attr] <=> e2.attributes[attr] }
        end
        elem.elements.each { |a| elem.elements.delete(a) }
        sorted.each { |a| elem.add_element(a) }
      end
    elsif element.is_a? REXML::Element
      sorted = case attr
               when 'text'
                 elem.elements.sort_by(&:text)
               when nil
                 elem.elements.sort_by(&:name)
               else
                 elem.elements.sort { |e1, e2| e1.attributes[attr] <=> e2.attributes[attr] }
               end
      element.elements.each { |a| element.elements.delete(a) }
      sorted.each { |a| element.add_element(a) }
    end
  end

  private

  def parser(string)
    parse = string.match(%r{^(\S+)\ (.*)$})
    return if parse.nil?

    cmd = parse[1]
    args = parse[2]
    case cmd
    when 'add'
      built_path = build_path(parse[2].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        @operations.push(proc { add(built_path[:final_path].first.parents, [built_path[:final_path].first.name]) })
      else
        @operations.push(proc { add(built_path[:final_path], built_path[:remainder]) })
      end
    when 'clear'
      # Break down the paths
      built_path = build_path(parse[2].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))

      if built_path[:exists] # Only clear if the thing exists
        @operations.push(proc { clear(built_path[:final_path]) })
      end
    when 'get'
      query = parse[2].match(%r{^(.*)\ (==|!=|<|>|<=|>=)\ \"(.*)\"$})
      raise ArgumentError if query.nil?
      attribute = query[1].match(/^(.*)([^\[]#attribute\/)(.*)$/)

      if attribute.nil?
        path = query[1]
        attr = nil
      else
        path = attribute[1]
        attr = attribute[3]
      end

      built_path = build_path(path.scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        @validations.push(proc { get(built_path[:final_path], query[2], query[3], attr) })
      else
        @validations.push(proc { evaluate_expression(nil, query[2], query[3]) })
      end
    when 'ins', 'insert'
      args = parse[2].match(%r{(.*)\ (before|after)\ (.*)$})
      raise ArgumentError if args.nil?
      built_path = build_path(args[3].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        args[1].scan(/\/(^\/)/).each do |item|
          puts item
        end
        case args[2]
        when 'before'
        when 'after'
        end
      end
    when 'match'
      query = parse[2].match(%r{(.*)\ size\ (==|!=|<|>|<=|>=)\ (\d)+$})
      raise ArgumentError if query.nil?

      built_path = build_path(query[1].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        @validations.push(proc { evaluate_expression(built_path[:final_path].size, query[2], query[3].to_i) })
      else
        @validations.push(proc { evaluate_expression(0, query[2], query[3]) })
      end
    when 'rm', 'remove'
      built_path = build_path(parse[2].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))

      if built_path[:exists] # Only clear if the thing exists
        @operations.push(proc { rm(built_path[:final_path]) })
      end
    when 'set'
      args = parse[2].match(%r{(.*)\ \"(.*)\"$})
      raise ArgumentError if args.nil?
      attribute = args[1].match(/^(.*)([^\[]#attribute\/)(.*)$/)

      if attribute.nil?
        path = args[1]
        attr = nil
      else
        path = attribute[1]
        attr = attribute[3]
      end

      built_path = build_path(path.scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        @operations.push(proc { set(built_path[:final_path], args[2], attr, nil) })
      else
        path = collapse_functions(path)
        @operations.push(proc { set(nil, args[2], attr, path) })
      end
    when 'sort'
      # sort /foo/bar [attribute|text] [desc|asc]
      args = parse[2].match(%r{(.*)(\ )?(.*|text)?(\ )?(desc|asc)?$})
      raise ArgumentError if args.nil?
      attribute = args[3]
      attr = if attribute.nil?
               nil
             else
               args[3]
             end

      built_path = build_path(args[1].scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/))
      if built_path[:exists]
        @operations.push(proc { sort(built_path[:final_path], attr, args[5]) })
      end
    else
      raise ArgumentError
    end
  end

  def build_path(args)
    # We should be getting the output of scan here so it should be an array of arrays
    raise ArgumentError unless args.is_a? Array
    remainder = args.map { |m| m.first }
    final_path = match('')
    exists = true

    args.each do |path|
      match = evaluate_match(self.match(path.first, final_path), path.last)
      if match.nil? || match.empty?
        exists = false
      else
        final_path = match
        remainder.delete(path.first)
      end
    end

    # Returns the lsast piece of the path that matched the criteria, if the full path exists, and any remaining components of the
    # path
    { final_path: final_path, exists: exists, remainder: remainder }
  end

  def collapse_functions(args)
    retval = ''
    cur_path = match('')
    args.scan(/\/([^\[\/]*)(\[[^\]\[]*\])?/).each do |path|
      cur_path = match(path.first, cur_path) unless cur_path.nil?
      ftest = path.last.to_s.match(%r{(last)\((.*)?\)(\+|\-)?(\d+)?})
      if ftest
        case ftest[1]
        when 'last'
          test = 0
          test = cur_path.size unless cur_path.nil? || cur_path.empty?
          if ftest[3] && ftest[4]
            append = "[#{evaluate_expression(test, ftest[3], ftest[4].to_i)}]"
          else
            cur_path = [cur_path.last] if cur_path
            append = "[#{test}]"
          end
        else
          append = ''
        end
        retval += "/#{path.first}#{append}"
      else
        retval += "/#{path.first}#{path.last}"
      end
      cur_path = nil if cur_path.nil? || evaluate_match(cur_path, path.last).nil?
    end
    retval
  end

  def evaluate_expression(attr, expr, val)
    # If attr and val are all digits assume an integer comparison
    if attr =~ %r{^(\d)+$} && val =~ %r{^(\d)+$}
      eval_attr = attr.to_i
      eval_val  = val.to_i
    else
      eval_attr = attr
      eval_val  = val
    end

    case expr
    when '=='
      return (eval_attr == eval_val)
    when '!='
      return (eval_attr != eval_val)
    when '+'
      return (attr + val)
    when '-'
      return (attr - val)
    # The rest are only math so we do a conversion to_i
    when '<'
      return (attr.to_i < val.to_i)
    when '>'
      return (attr.to_i > val.to_i)
    when '<='
      return (attr.to_i <= val.to_i)
    when '>='
      return (attr.to_i >= val.to_i)
    end
    raise ArgumentError
  end

  def evaluate_match(match, args)
    return match unless args.is_a? String
    retval = match
    args.split('][').each do |evaluate|
      evaluate.gsub!(%r{^[\[]}, '').chomp!(']')
      parse = evaluate.match(/(#attribute\/)?(.*)?\ (==|!=|\<|\>|<=|>=)\ \"(.*)\"/)
      if parse.nil?
        # Either a size check or a function
        if evaluate.match?(%r{^(\[)?(\d+)(\])?$}) # All digits, must be an index variables
          index = evaluate.match(%r{^(\[)?(\d+)(\])?$})[2].to_i - 1
          return nil if (match.length < index) || !retval.include?(match[index])
          retval = [match[index]]
        else  # Function or bust!
          parse = evaluate.match(%r{(last)\((.*)?\)(\+|\-)?(\d+)?$})
          return nil unless parse
          case parse[1]
          when 'last'
            if parse[3]
              return nil if parse[3] == '+'
              # Must be '-', right?  This isn't a dangerous assumption AT ALL
              raise ArgumentError unless parse[4]
              # test = match[match.length() - parse[4].to_i]
              return nil unless retval.include?(match[match.length - parse[4].to_i])
              retval = [match[match.length - parse[4].to_i]]
            else
              return nil unless retval.include?(match.last)
              retval = [match.last]
            end
          end
        end
      else # Attribute or value evaluation
        retval = if parse[1]
                   retval.select do |a|
                     a if a.attributes.keys.include?(parse[2]) &&
                          evaluate_expression(a.attributes[parse[2]], parse[3], parse[4])
                   end

                 else
                   retval.select { |a| a if evaluate_expression(a.text, parse[3], parse[4]) }
                 end
      end
    end
    return nil if retval.empty?
    retval
  end
end
