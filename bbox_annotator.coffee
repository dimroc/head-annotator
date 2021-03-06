# Use coffee-script compiler to obtain a javascript file.
#
#    coffee -c bbox_annotator.coffee
#
# See http://coffeescript.org/

# BBox selection window.
class BBoxSelector
  # Initializes selector in the image frame.
  constructor: (image_frame, options) ->
    options ?= {}
    options.input_method ||= "text"
    @image_frame = image_frame
    @border_width = options.border_width || 2
    @selector = $('<div class="bbox_selector"></div>')
    @selector.css
      "border": (@border_width) + "px dotted rgb(127,255,127)",
      "position": "absolute"
    @image_frame.append @selector
    @selector.css
      "border-width": @border_width
    @selector.hide()
    this.create_label_box(options)

  # Initializes a label input box.
  create_label_box: (options) ->
    options.labels ||= ["object"]
    @label_box = $('<div class="label_box"></div>')
    @label_box.css
      "position": "absolute"
    @image_frame.append @label_box
    switch options.input_method
      when 'dot'
        options.labels = options.labels[0] if $.isArray options.labels
        @label_input = $('<input class="label_input" name="label" type="text">')
        @label_box.append @label_input
        @label_input.val(options.labels)
      when 'select'
        options.labels = [options.labels] if typeof options.labels == "string"
        @label_input = $('<select class="label_input" name="label"></select>')
        @label_box.append @label_input
        @label_input.append($('<option value>choose an item</option>'))
        for label in options.labels
          @label_input.append '<option value="' + label + '">' +
                              label + '</option>'
        @label_input.change (e) -> this.blur()
      when 'text'
        options.labels = [options.labels] if typeof options.labels == "string"
        @label_input = $('<input class="label_input" name="label" ' +
                         'type="text" value>')
        @label_box.append @label_input
        @label_input.autocomplete
          source: options.labels || ['']
          autoFocus: true
      when 'fixed'
        options.labels = options.labels[0] if $.isArray options.labels
        @label_input = $('<input class="label_input" name="label" type="text">')
        @label_box.append @label_input
        @label_input.val(options.labels)
      else
        throw 'Invalid label_input parameter: ' + options.input_method

    options.interactive = options.input_method in ['fixed', 'dot']
    @label_box.hide()

  # Crop x and y to the image size.
  crop: (pageX, pageY) ->
    point =
      x: Math.min(Math.max(Math.round(pageX - @image_frame.offset().left), 0),
                           Math.round(@image_frame.width()-1))
      y: Math.min(Math.max(Math.round(pageY - @image_frame.offset().top), 0),
                           Math.round(@image_frame.height()-1))

  # When a new selection is made.
  start: (pageX, pageY) ->
    @pointer = this.crop(pageX, pageY)
    @offset = @pointer
    this.refresh()
    @selector.show()
    $('body').css('cursor', 'crosshair')
    document.onselectstart = () ->
      false

  add_point: (pageX, pageY) ->
    @offset = this.crop(pageX, pageY)
    @pointer = this.crop(pageX+2, pageY+2)
    #this.refresh()
    data = this.rectangle()
    data.label = $.trim(@label_input.val().toLowerCase())
    data

  # When a selection updates.
  update_rectangle: (pageX, pageY) ->
    @pointer = this.crop(pageX, pageY)
    this.refresh()

  # When starting to input label.
  input_label: (options) ->
    $('body').css('cursor', 'default')
    document.onselectstart = () ->
      true
    #@label_box.show()
    @label_input.focus()

  # Finish and return the annotation.
  finish: (options) ->
    @label_box.hide()
    @selector.hide()
    data = this.rectangle()
    data.label = $.trim(@label_input.val().toLowerCase())
    @label_input.val('') unless options.interactive
    data

  # Get a rectangle.
  rectangle: () ->
    x1 = Math.min(@offset.x, @pointer.x)
    y1 = Math.min(@offset.y, @pointer.y)
    x2 = Math.max(@offset.x, @pointer.x)
    y2 = Math.max(@offset.y, @pointer.y)
    rect =
      left: x1
      top: y1
      width: x2 - x1 + 1
      height: y2 - y1 + 1

  # Update css of the box.
  refresh: () ->
    @selector.css(
      left: (@pointer.x-2) + 'px'
      top: (@pointer.y-2) + 'px'
      width: '4px'
      height: '4px'
    )
    @label_box.css(
      left: @pointer.x + 'px'
      top: (@pointer.y - 5) + 'px'
    )

  # Return input element.
  get_input_element: () ->
    @label_input

# Annotator object definition.
class @BBoxAnnotator
  # Initialize the annotator layout and events.
  constructor: (options) ->
    annotator = this
    @annotator_element = $(options.id || "#bbox_annotator")
    @border_width = options.border_width || 2
    @show_label = false # options.show_label || (!options.interactive)
    @image_frame = $('<div class="image_frame"></div>')
    @annotator_element.append @image_frame
    image_element = new Image()
    image_element.src = options.url
    image_element.onload = () ->
      options.width ||= image_element.width
      options.height ||= image_element.height
      annotator.annotator_element.css
        "width": (options.width + annotator.border_width * 2) + 'px',
        "height": (options.height + annotator.border_width * 2) + 'px',
        "cursor": "crosshair"
      annotator.image_frame.css
        "background-image": "url('" + image_element.src + "')",
        "width": options.width + "px",
        "height": options.height + "px",
        "position": "relative"
      annotator.selector = new BBoxSelector(annotator.image_frame, options)
      annotator.initialize_events(annotator.selector, options)
    image_element.onerror = () ->
      annotator.annotator_element.text "Invalid image URL: " + options.url
    @entries = []
    @onchange = options.onchange

  # Initialize events.
  initialize_events: (selector, options) ->
    status = 'free'
    @hit_menuitem = false
    annotator = this
    @annotator_element.mouseup (e) ->
      unless annotator.hit_menuitem
        switch status
          when 'free', 'input'
            selector.get_input_element().blur() if status == 'input'
            if e.which == 1 # left button
              data = selector.add_point(e.pageX, e.pageY)
              console.log "data: #{data.left} #{data.top}"
              annotator.add_entry data
              annotator.onchange annotator.entries if annotator.onchange
              status = 'free'

      annotator.hit_menuitem = false
      true
    #$(window).mousemove (e) ->
      #switch status
        #when 'hold'
          #selector.update_rectangle(e.pageX, e.pageY)
      #true
    $(window).mouseup (e) ->
      console.log status
      #switch status
        #when 'hold'
          #selector.update_rectangle(e.pageX, e.pageY)
          #selector.input_label(options)
          #status = 'input'
          #selector.get_input_element().blur() if options.interactive
      true
    selector.get_input_element().blur (e) ->
      switch status
        when 'input'
          data = selector.finish(options)
          if data.label
            annotator.add_entry data
            annotator.onchange annotator.entries if annotator.onchange
          status = 'free'
      true
    selector.get_input_element().keypress (e) ->
      switch status
        when 'input'
          selector.get_input_element().blur() if e.which == 13
      e.which != 13
    selector.get_input_element().mousedown (e) ->
      annotator.hit_menuitem = true
    selector.get_input_element().mousemove (e) ->
      annotator.hit_menuitem = true
    selector.get_input_element().mouseup (e) ->
      annotator.hit_menuitem = true
    selector.get_input_element().parent().mousedown (e) ->
      annotator.hit_menuitem = true

  # Add a new entry.
  add_entry: (entry) ->
    @entries.push entry
    box_element = $('<div class="annotated_bounding_box"></div>')
    box_element.appendTo(@image_frame).css
      "border": @border_width + "px solid rgb(127,255,127)",
      "position": "absolute",
      "top": (entry.top - @border_width) + "px",
      "left": (entry.left - @border_width) + "px",
      "width": entry.width + "px",
      "height": entry.height + "px",
      "color": "rgb(127,255,127)",
      "font-family": "monospace",
      "font-size": "small",
      "margin": "-1px" # Simple way to center box over clicked point without manipulating data
    close_button = $('<div></div>').appendTo(box_element).css
      "position": "absolute",
      "top": "-8px",
      "right": "-8px",
      "width": "16px",
      "height": "0",
      "padding": "16px 0 0 0",
      "overflow": "hidden",
      "color": "#fff",
      "background-color": "#030",
      "border": "2px solid #fff",
      "-moz-border-radius": "18px",
      "-webkit-border-radius": "18px",
      "border-radius": "18px",
      "cursor": "pointer",
      "-moz-user-select": "none",
      "-webkit-user-select": "none",
      "user-select": "none",
      "text-align": "center"
    $("<div></div>").appendTo(close_button).html('&#215;').css
      "display": "block",
      "text-align": "center",
      "width": "16px",
      "position": "absolute",
      "top": "-2px",
      "left": "0",
      "font-size": "16px",
      "line-height": "16px",
      "font-family": '"Helvetica Neue", Consolas, Verdana, Tahoma, Calibri, ' +
                     'Helvetica, Menlo, "Droid Sans", sans-serif',
    text_box = $('<div></div>').appendTo(box_element).css
      "overflow": "hidden"
    text_box.text(entry.label) if @show_label
    annotator = this
    box_element.hover ((e) -> close_button.show()), ((e) -> close_button.hide())
    close_button.mousedown (e) ->
      annotator.hit_menuitem = true
    close_button.click (e) ->
      clicked_box = close_button.parent(".annotated_bounding_box")
      index = clicked_box.prevAll(".annotated_bounding_box").length
      clicked_box.detach()
      annotator.entries.splice index, 1
      annotator.onchange annotator.entries
    close_button.hide()
  # Clear all entries.
  clear_all: (e) ->
    @annotator_element.find(".annotated_bounding_box").detach()
    this.entries.splice 0
    this.onchange this.entries
