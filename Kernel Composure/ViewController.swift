//
//  ViewController.swift
//  Kernel Composure
//
//  Created by Tyler Sparr on 5/17/20.
//  Copyright © 2020 Encore Technologies. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
//  Defines our button at the top of the window
    @IBOutlet weak var kernelPanicSelection: NSButton!
    
//  Defines the box where we output our text
    @IBOutlet weak var kernelPanicText: NSTextView!
    
//  Action connected to our button, opens file selection
    @IBAction func handleKernelPanicSelection(_ sender: Any) {
        let dialog = NSOpenPanel();
    
        dialog.title                   = "Choose the Kernel Panic log";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        dialog.allowedFileTypes        = ["panic"];
    
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url
    
            if (result != nil) {

                basic_parse_kernel_panic(file_name: result!)
                
            }
    
        } else {
            // User clicked on "Cancel"
            return
        }
    }
    
//  Action connected to View - > Show Advanced menu button
    @IBAction func handleAdvancedViewSelection(_ sender: Any) {
//      Check if there's already text in our view
        let panic_string = (kernelPanicText.textStorage as NSAttributedString?)?.string
        
//      If there's text, pull the filename and reparse gathering and displaying all info
        if panic_string != nil {
            let lines = panic_string!.split(whereSeparator: \.isNewline)
            let filename = lines[1].trimmingCharacters(in: .whitespaces)
            let fileUrl = URL(fileURLWithPath: filename)
            
            advanced_parse_kernel_panic(file_name: fileUrl)
            
            }
        else {
            return
        }
    }
    
//  Action connected to Help -> Kernel Composure Help menu button
    @IBAction func getMoreInfo(_ sender: Any) {
        let url = URL(string: "https://developer.apple.com/library/archive/technotes/tn2063/_index.html")!
        NSWorkspace.shared.open(url)
    }
    
//  This is called from AppDelegate.swift if the file is opened by "Open With"
//  rather than via our GUI button
    func automatic_run(_ filename: URL) {
    
        basic_parse_kernel_panic(file_name: filename)
       
    }
   
//  Make sure we start off with a blank, uneditable view that supports rich text
    func setupUI() {
        kernelPanicText.string = ""
        kernelPanicText.isEditable = false
        kernelPanicText.isRichText = true
    }
    
//  Reads the file line by line and adds the lines to an array
    func loadFile(file_path:URL) ->  Array<String>{
        var panic_log_lines: [String] = []
        let path:String = file_path.path
        let reader = LineReader(path: path)
        for line in reader! {
            panic_log_lines.append(line)
        }
        return panic_log_lines
    }
    
//  Parse the first line of the Kernel Panic log and return it as a JSON object
    func get_initial_info(panic_log_lines:Array<String>) -> JSON{
        let initial_info = panic_log_lines[0]
        let json = JSON.init(parseJSON:initial_info)

        return(json)
    }
    
//  Parse the second line of the Kernel Panic log and return it as a JSON object
    func get_panic_string(panic_log_lines:Array<String>) -> JSON{
        let panic_string = panic_log_lines[1]
        let json = JSON.init(parseJSON:panic_string)

        return(json)
    }
    
//  Get the kernel extensions in backtrace via brute force text parsing
    func get_backtrace(panic_string:JSON) -> Array<String>{
        var process_info: [String] = []
        let panic_string = panic_string["macOSPanicString"].stringValue
        let lines = panic_string.split(whereSeparator: \.isNewline)
        
//      Find where the backtrace starts
        let backtraceIndex = lines.firstIndex(of: "      Kernel Extensions in backtrace:")!

        for line in lines {
//          Find where the backtrace ends
            if line.contains("BSD process name corresponding to current thread") {
                let process_name_line = lines.firstIndex(of: line)
                
//              Copy everything in between the two lines to get our full backtrace
                let backtrace_values = lines[backtraceIndex..<process_name_line!]
                for line in backtrace_values {
//                  Bold the first line in the backtrace
                    if backtrace_values.first == line {
                        let stripped_line = line.trimmingCharacters(in: .whitespaces)
                        process_info.append("<b>\(stripped_line)</b>")
                    }
//                  Indent all dependencies
                    if line.contains("dependency"){
                        let stripped_line = line.trimmingCharacters(in: .whitespaces)
                        process_info.append("&nbsp; &nbsp; &nbsp; &nbsp;\(stripped_line)<br>")
                    } else {
                    let stripped_line = line.trimmingCharacters(in: .whitespaces)
                    process_info.append("\(stripped_line)<br>")
                    }
                }
//              Get the process name by splitting by colon
                let process_name = line.components(separatedBy: ":")
                let process_name_txt = process_name[1]
                process_info.append("<br><br><b>Last process before crash:</b> \(process_name_txt)<br>")
            }
        }
        return process_info
    }
    
//  Build our basic output with all of the necessary HTML formatting
    func build_initial_output(file_name: URL, initial_info:JSON, panic_string:JSON, process_info:Array<String>) -> NSAttributedString{
        var initial_output: [String] = []
        let path:String = file_name.path
        initial_output.append("<b>filename:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(path)<br>")
        let timestamp = initial_info["timestamp"].stringValue
        initial_output.append("<b>timestamp:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(timestamp)<br>")
        let bug_type = initial_info["bug_type"].stringValue
        initial_output.append("<b>bug_type:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(bug_type)<br>")
        let os_version = initial_info["os_version"].stringValue
        initial_output.append("<b>os_version:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(os_version)<br>")
            
        let initial_output_text = initial_output.joined(separator: "\n")
            
        var process_text = process_info.joined(separator: ",")
        process_text = process_text.replacingOccurrences(of: ",", with: "", options: NSString.CompareOptions.literal, range:nil)
            
        let full_panic_text = initial_output_text + "<br><br>" + process_text
            
//      We need to convert from String to Data to use HTML formatting
        let panic_html = full_panic_text.data(using: .utf8)!
            
//      Tell it we want our Data to be parsed as HTML and make it mutable
        let formatted_panic = NSMutableAttributedString(html: panic_html, documentAttributes: nil)!
            
//      We need to get the full length so we can apply formatting to the whole string
        let panic_range = NSMakeRange(0, formatted_panic.length)
            
//      This is necessary for automatic Dark Mode support
        formatted_panic.addAttribute(.foregroundColor, value: NSColor.textColor, range: panic_range)
        
        return formatted_panic
    }
    
//  Build our entire output with necessary HTML formatting
    func build_full_output(file_name: URL, initial_info:JSON, panic_string:JSON, process_info:Array<String>) -> NSAttributedString{
        var initial_output: [String] = []
        let path:String = file_name.path
        initial_output.append("<b>filename:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(path)<br>")
        let timestamp = initial_info["timestamp"].stringValue
        initial_output.append("<b>timestamp:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(timestamp)<br>")
        let bug_type = initial_info["bug_type"].stringValue
        initial_output.append("<b>bug_type:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(bug_type)<br>")
        let os_version = initial_info["os_version"].stringValue
        initial_output.append("<b>os_version:</b> <br>&nbsp; &nbsp; &nbsp; &nbsp;\(os_version)<br>")
        
        let initial_output_text = initial_output.joined(separator: "\n")
        
        var process_text = process_info.joined(separator: ",")
        process_text = process_text.replacingOccurrences(of: ",", with: "", options: NSString.CompareOptions.literal, range:nil)
        
        var panic_string = panic_string["macOSPanicString"].stringValue
        panic_string = panic_string.replacingOccurrences(of: "\n", with: "<br>", options: NSString.CompareOptions.literal, range:nil)
        
        while panic_string.hasSuffix("<br>"){
            panic_string = String(panic_string.dropLast(4))
        }
        
        let full_panic_text = initial_output_text + "<br><br>" + process_text + "<br><br>" + "<b>Full Panic String:</b><br>" + panic_string
        
//      We need to convert from String to Data to use HTML formatting
        let panic_html = full_panic_text.data(using: .utf8)!
        
//      Tell it we want our Data to be parsed as HTML and make it mutable
        let formatted_panic = NSMutableAttributedString(html: panic_html, documentAttributes: nil)!
        
//      We need to get the full length so we can apply formatting to the whole string
        let panic_range = NSMakeRange(0, formatted_panic.length)
        
//      This is necessary for automatic Dark Mode support
        formatted_panic.addAttribute(.foregroundColor, value: NSColor.textColor, range: panic_range)
    
        return formatted_panic
    }
    
//  Combines all of our basic parsing functions together for initial output
    func basic_parse_kernel_panic(file_name: URL) {
        let panic_text_array = loadFile(file_path: file_name)
        
        let initial_info = get_initial_info(panic_log_lines: panic_text_array)
        
        if initial_info != JSON.null {
            let panic_string = get_panic_string(panic_log_lines: panic_text_array)
            
            let process_info = get_backtrace(panic_string: panic_string)
            
            let initial_output = build_initial_output(file_name: file_name, initial_info: initial_info, panic_string: panic_string, process_info: process_info)
            
            kernelPanicText.textStorage?.setAttributedString(initial_output)
            
        } else {
            kernelPanicText.string = "Currently I can only parse Kernel Panic logs generated from macOS 10.15.x. Please select a different log."
            return
        }
    }
    
//  Combines all parsing functions together for full output
    func advanced_parse_kernel_panic(file_name: URL) {
        let panic_text_array = loadFile(file_path: file_name)
                        
        let initial_info = get_initial_info(panic_log_lines: panic_text_array)
                        
        if initial_info != JSON.null {
            let panic_string = get_panic_string(panic_log_lines: panic_text_array)
                            
            let process_info = get_backtrace(panic_string: panic_string)
                            
            let full_output = build_full_output(file_name: file_name, initial_info: initial_info, panic_string: panic_string, process_info: process_info)
            
            kernelPanicText.textStorage?.setAttributedString(full_output)
                            
            } else {
                kernelPanicText.string = "Currently I can only parse Kernel Panic logs generated from macOS 10.15.x. Please select a different log."
                return
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

// Do any additional setup after loading the view.
// Default function, we're not using
    }
    
//  Just does our initial UI setup
    override func viewWillAppear() {
        super.viewWillAppear()
     
        setupUI()
    }

    override var representedObject: Any? {
        didSet {
// Update the view, if already loaded.
// Default function, we're not using
        }
    }


}
