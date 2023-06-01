init_simple_logging :: ( level: string ) -> bool {
  log_level : Log_Level;
  #insert #run -> string {
    builder: String_Builder;

    #if 0 {
      // Output of the following messy metaprogrogramming is something like:
      if level == {
        case "FIRST"; log_level = .FIRST;
        case "NEXT"; log_level = .FIRST;
        case; log_error(); return false;
      }
    }

    append( *builder, "if level == {");
      do_one_element :: #string DONE
        case "%1"; log_level = .%1;
      DONE

      for em : type_info( Log_Level ).names {
        append( *builder, tprint( do_one_element, em ) );
      }

      defer reset(*builder);

      otherwise_case :: #string DONE
        case;
          log_error( "Unrecognised log level %. Valid: %",
                      level,
                      type_info( Log_Level ).names );
          return false;
      DONE

      append( *builder, otherwise_case );
    append( *builder, "}");

    return builder_to_string( *builder );
  };
  context.logger = logger;
  context.log_level = log_level;
  return true;
}

log :: ( level: Log_Level,
         format_string: string,
         args: .. Any,
         loc := #caller_location ) {

  flags := Log_Flags.NONE;
  if #complete level == {
    case .NORMAL;
    case .VERBOSE;
      flags |= .VERBOSE_ONLY;
    case .VERY_VERBOSE;
      flags |= .VERY_VERBOSE_ONLY;
  }

  log( format_string, .. args , loc, flags );

} @PrintLike

logger :: (message: string, data: *void, info: Log_Info) {
  if context.log_level <= .NORMAL &&
     ( info.common_flags & .VERBOSE_ONLY ||
       info.common_flags & .VERY_VERBOSE_ONLY ) {
    return;
  } else if context.log_level <= .VERBOSE &&
            info.common_flags & .VERY_VERBOSE_ONLY {
    return;
  }

  // HACK: Copy/paste of runtime_support_default_logger
  to_standard_error := (info.common_flags & .ERROR) != 0;

  if message[message.count-1] != #char "\n" {
    write_strings(message, "\n", to_standard_error = to_standard_error);
  } else {
    write_string(message, to_standard_error = to_standard_error);
  }
}

#import "Basic";
