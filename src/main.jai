FRAME_TICK := 1.0/30.0; // update at around 30fps.
VER_MAJOR  := 1;
VER_MINOR  := 0;

Options :: struct {
  runtime_dir := ".";           @"?Runtime directory of this application";
  data_dir    := "data";        @"?Directory under runtime_dir";
  log_level   := "NORMAL";      @"?Levels: NORMAL, VERBOSE, VERY_VERBOSE";
}
options: Options;

main :: () {
  #if OS == .WINDOWS {
    Windows :: #import "Windows";
    Windows.SetProcessDPIAware();

    // Windows is very bad at thread-switching by default unless you do this.
    Windows.timeBeginPeriod(1);
  }

  {
    ok: bool;
    ok, options = parse_arguments( Options, .ALIGN_HELP );
    if !ok {
      log_error( "Unable to parse command line" );
      exit( 1 );
    }
  }

  if !init_simple_logging( options.log_level ) {
    exit( 1 );
  }
  log( .VERBOSE, "normal LSP Tester v%.%", VER_MAJOR, VER_MINOR );

  set_cwd();
  init_time();
  window := init_ui();

  file_data := read_entire_file( "data/test.jaiw" );
  file_lines = String.split( file_data, "\n" );

  quit := false;

  while !quit {
    reset_temporary_storage();

    current_time = get_time();
    current_dt : float = cast(float)(current_time - last_time);
    if current_dt > FRAME_TICK current_dt = FRAME_TICK;

    delay : float = FRAME_TICK - current_dt;
    if delay > 0.001 {
      // wait; we don't want to do too many pesky frames
      sleep_for : s32 = xx ( delay * 1000.0 + 0.5 );
      // TODO: THis is probably wrong/lame. Timers are so shitty, but it's
      // probably close enough for this sort of app.
      sleep_milliseconds( sleep_for );
    }

    // Frame starts now, however shitty the above timer/sleep is
    last_time = get_time();

    for Input.get_window_resizes() {
      if it.window == window {
        handle_window_resize( window, it.width, it.height );
      }
    }

    Input.update_window_events();
    for Input.events_this_frame {
      GR.getrect_handle_event( it );

      if #complete it.type == {
        case .UNINITIALIZED;
          // ignore
        case .KEYBOARD;
          if it.key_pressed && it.key_code == .ESCAPE {
            GR.active_widget_deactivate_all();
          }
        case .TEXT_INPUT;
        case .WINDOW;
        case .MOUSE_WHEEL;
        case .QUIT; quit = true;
        case .DRAG_AND_DROP_FILES;
      }
    }

    draw_frame( window, current_dt );
    Simp.swap_buffers( window );
  }

}

#scope_file;

init_ui :: () -> Window_Type {
  window := create_window( window_width, window_height, "LSP Tester" );

  {
    x, y, w, h := get_dimensions(window, false);
    window_width = w;
    window_height = h;
  }

  Simp.set_render_target( window );
  init_fonts();

  GR.ui_init();
  return window;
}

handle_window_resize :: ( window: Window_Type, width: s32, height: s32 ) {
  Simp.update_window(window);
  should_reinit := ( width != window_width ) || ( height != window_height );

  window_width  = width;
  window_height = height;

  if should_reinit init_fonts();
}

file_lines: []string;

draw_frame :: ( window: Window_Type, dt: float ) {
  Simp.clear_render_target( .7, .7, .7, 1 );

  GR.ui_per_frame_update(window,
                         xx window_width,
                         xx window_height,
                         current_time );

  base_theme := GR.default_theme_procs[ GR.Default_Themes.Nimbus ]();

  // 'k' is some resolution-adjusting unit of distance. Currently 1/10 of the
  // screen height. (copied from GetRect example; perhaps we can adjust this)
  k := window_height * .1;
  // {
  //   theme := base_theme.button_theme;
  //   theme.font = fonts[ Font_Style.NORMAL ];
  //   if GR.button( GR.get_rect( k, k, k * 3, k / 2.0 ), "Click Me", *theme ) {
  //     Simp.draw_text( fonts[ Font_Style.MONO ],
  //                     xx (3*k),
  //                     xx (3*k),
  //                     "Clicked!" );
  //   }
  // }

  // draw the file contents in a box in the middle of the screen
  {
    font := fonts[ Font_Style.MONO ];
    max_width := Simp.prepare_text( font, ONE_LINE );

    border := k*0.1;
    frame_width := border * 0.1;

    y := window_height - border;
    x := (window_width - max_width) / 2.0;

    // put a box around it.
    wrap_x := x - frame_width;
    wrap_y := border - frame_width;
    wrap_width := max_width + 2*frame_width;
    wrap_height := window_height - 2*border + 2*frame_width;

    Simp.set_shader_for_color( true );

    r := GR.get_rect( wrap_x, wrap_y, wrap_width, wrap_height );
    p0,p1,p2,p3 := GR.get_quad( r );
    Simp.immediate_quad( p0, p1, p2, p3,
                         base_theme.background_color );

    r = GR.get_rect( wrap_x + frame_width,
                     wrap_y + frame_width,
                     xx max_width,
                     xx window_height - 2*border );

    p0,p1,p2,p3 = GR.get_quad( r );
    Simp.immediate_quad( p0, p1, p2, p3,
                         base_theme.background_color_bright );

    Simp.immediate_flush();

    // Set the scissor to avoid drawing over the borders...
    {
      GR.push_scissor( r );
      y -= font.default_line_spacing; // because y is the bottom-left-corner
      for file_lines {
        Simp.draw_text( font, xx x, xx y, it,
                        base_theme.text_color );
        y -= font.default_line_spacing;
        if y < 0 {
          break;
        }
      }
    }
    GR.pop_scissor();
  }
}

#scope_file

ONE_LINE :: "................................................................................";

Font_Style :: enum {
  NORMAL;
  MONO;
};

init_fonts :: () {
  // there seems to be no way to free Dynamic_Fonts. shrug.
  array_reset( *fonts );

  pixel_height := window_height / 50;

  // Generate a call to load each font in Font_Style
  #insert #run -> string {
    builder: String_Builder;

    load_one :: #string DONE
    {
      font := Simp.get_font_at_size( options.data_dir, "%1.ttf", pixel_height );
      if !font {
        log_error( "Unable to load font %1" );
        exit( 1 );
      }
      array_add( *fonts, font );
    }
    DONE

    defer reset( *builder );
    for em : type_info( Font_Style ).names {
      append( *builder, tprint( load_one, em ) );
    }
    return builder_to_string( *builder );
  };

  log( .VERBOSE, "Loaded % fonts from %", fonts.count, options.data_dir );
}

fonts : [..]*Simp.Dynamic_Font;
window_width := 1280;
window_height := 720;
last_time: float64;
current_time: float64;

set_cwd :: () {
  if options.runtime_dir && set_working_directory( options.runtime_dir ) {
    return;
  }

  System :: #import "System";
  set_working_directory(System.get_path_of_running_executable());
}

#import "Window_Creation";
#import "Basic";
#import "File";
#import "Command_Line";
#import "Simple_Logger";

String :: #import "String";
Math:: #import "Math";
Simp :: #import "Simp";
GR :: #import "GetRect";
Input :: #import "Input";
