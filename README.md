# Log4Xojo

Log4Xojo is a lightweight and thread-safe logging framework designed for Xojo applications. It provides robust logging capabilities, including support for multiple log levels, dynamic log file naming, file rotation, and asynchronous logging using a background thread.

To learn more about this class, check out: https://blog.xojo.com/2024/11/26/log4xojo-a-more-powerful-way-to-manage-your-app-logging/.

---

## Features

- **Thread-Safe Logging**: Handles concurrent log messages across multiple threads.
- **Multiple Log Levels**: Supports `Debug`, `Info`, `Warning`, `Error`, and `Critical` levels.
- **Dynamic File Naming**: Includes the log name and current date in log file names for better organization.
- **File Rotation**: Automatically rotates log files based on size with configurable backup limits.
- **Multiple Destinations**: Log messages can be sent to:
  - Debug console (`DebugLog`)
  - System logger (`SystemLog`)
  - Log files (`FileLog`)
  - All destinations (`All`)
- **Customizable File Path**: Allows specifying a base directory for log files.

---

## Usage Example

### Basic Example
```xojo
// Create a logger instance
Var appLog As New Log4Xojo("AppLog")

// Set the base location for log files
appLog.SetLogFilePath(SpecialFolder.Documents)

// Configure the logger
appLog.SetLogLevel(Log4Xojo.LogLevel.Info)
appLog.SetLogDestinations(Log4Xojo.LogDestination.FileLog)

// Log some messages
appLog.Log("Application started", Log4Xojo.LogLevel.Info)
appLog.Log("This is a warning", Log4Xojo.LogLevel.Warning)
appLog.Log("Critical error occurred", Log4Xojo.LogLevel.Critical, CurrentMethodName)

// Stop logging when done
appLog.StopLogging()
```

### Rotating Logs by Size
```xojo
// Set maximum log file size (e.g., 1 MB)
appLog.SetMaxLogFileSize(1024 * 1024) // 1 MB

// Set the maximum number of backup files
appLog.SetMaxBackupFiles(5)
```


## Contributing
Contributions are welcome!

## License
This project is licensed under the MIT License. See the <a href="LICENSE">LICENSE</a> file for details

## Acknowledgements
This class was inspired by popular logging frameworks such as <a href="https://logging.apache.org/log4j/">Log4J</a> and <a href="https://logging.apache.org/log4net/">Log4Net</a>, adapted for the Xojo ecosystem.
