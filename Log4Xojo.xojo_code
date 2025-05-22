#tag Class
Protected Class Log4Xojo
	#tag Method, Flags = &h0
		Sub Constructor(Name As String)
		  If Name.Trim = "" Then
		    Raise New InvalidArgumentException("Log name cannot be empty.")
		  End If
		  
		  // Set the log name
		  mLogName = Name
		  
		  // Initialize log level
		  mCurrentLogLevel = LogLevel.Debug
		  
		  // Initialize default log destinations
		  mLogDestinations.Add(LogDestination.DebugLog)
		  
		  // Set the log file path using the log name and current date
		  mLogFilePath = SpecialFolder.Documents.Child(GenerateLogFileName()).NativePath
		  
		  // Initialize the Mutex with the log name to ensure uniqueness
		  mLogQueueMutex = New Mutex("Log4Xojo_" + Name)
		  
		  // Set up a background thread for logging only if not in DebugBuild
		  #If Not DebugBuild Then
		    mLogThread = New Thread
		    AddHandler mLogThread.Run, AddressOf LogThreadHandler
		    mRunning = True
		    mLogThread.Start
		  #EndIf
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Destructor()
		  // // Wait for remaining messages with a timeout
		  // Var startTime As Double = System.Microseconds
		  // Const TimeoutMicroseconds = 5000000 // 5 seconds
		  // 
		  // While mLogQueue.Count > 0
		  // mLogThread.SleepCurrent(mThreadSleepDuration)
		  // 
		  // // Prevent infinite wait
		  // If System.Microseconds - startTime > TimeoutMicroseconds Then
		  // System.DebugLog("Log4Xojo: Timeout waiting for log queue to clear")
		  // Exit
		  // End If
		  // Wend
		  // 
		  // // Stop the thread
		  // If mLogThread <> Nil Then
		  // mLogThread.Stop
		  // End If
		  
		  StopLogging
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function GenerateLogFileName() As String
		  Var currentDate As String = DateTime.Now.SQLDate // Get the current date in YYYY-MM-DD format
		  Return mLogName + "_" + currentDate + ".txt"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Log(message As String, level As LogLevel, Optional location As String = "")
		  #If Not DebugBuild Then
		    // Check if the current message level is high enough to be logged
		    If Integer(level) < Integer(mCurrentLogLevel) Then
		      Return // Don't log messages below the current log level
		    End If
		    
		    // Prepare the log message with timestamp and log level
		    Var formattedMessage As String
		    Var timestamp As String
		    timestamp = DateTime.Now.SQLDateTime
		    
		    Var l As String = StringValue(level)
		    
		    // Construct the message with optional location
		    If location = "" Then
		      formattedMessage = "[" + timestamp + "] [" + l + "] " + message
		    Else
		      formattedMessage = "[" + timestamp + "] [" + location + "] [" + l + "] " + message
		    End If
		    
		    // Existing logging logic remains the same
		    For Each destination As LogDestination In mLogDestinations
		      Select Case destination
		      Case LogDestination.DebugLog
		        System.DebugLog(formattedMessage)
		        
		      Case LogDestination.SystemLog
		        System.Log(SystemLogLevelFromLogLevel(level), formattedMessage)
		        
		      Case LogDestination.FileLog
		        // Use mutex when adding to queue
		        mLogQueueMutex.Enter
		        Try
		          mLogQueue.Add(formattedMessage)
		        Finally
		          mLogQueueMutex.Leave
		        End Try
		        
		      Case LogDestination.All
		        System.DebugLog(formattedMessage)
		        System.Log(SystemLogLevelFromLogLevel(level), formattedMessage)
		        
		        // Use mutex when adding to queue
		        // Optional: Prevent queue from growing too large
		        mLogQueueMutex.Enter
		        Try
		          If mLogQueue.Count >= MaxQueueSize Then
		            // Optionally: Remove oldest message to make room
		            mLogQueue.RemoveAt(0)
		          End If
		          
		          // Add new message
		          mLogQueue.Add(formattedMessage)
		        Finally
		          mLogQueueMutex.Leave
		        End Try
		      End Select
		    Next
		  #Else
		    // In DebugBuild, handle logging synchronously to avoid async issues
		    If Integer(level) < Integer(mCurrentLogLevel) Then
		      Return // Don't log messages below the current log level
		    End If
		    
		    Var formattedMessage As String
		    Var timestamp As String = DateTime.Now.SQLDateTime
		    Var l As String = StringValue(level)
		    
		    If location = "" Then
		      formattedMessage = "[" + timestamp + "] [" + l + "] " + message
		    Else
		      formattedMessage = "[" + timestamp + "] [" + location + "] [" + l + "] " + message
		    End If
		    
		    For Each destination As LogDestination In mLogDestinations
		      Select Case destination
		      Case LogDestination.DebugLog
		        System.DebugLog(formattedMessage)
		      Case LogDestination.SystemLog
		        System.Log(SystemLogLevelFromLogLevel(level), formattedMessage)
		      Case LogDestination.FileLog
		        // Synchronously log to DebugLog in DebugBuild to avoid async file logging
		        System.DebugLog(formattedMessage)
		      Case LogDestination.All
		        System.DebugLog(formattedMessage)
		        System.Log(SystemLogLevelFromLogLevel(level), formattedMessage)
		      End Select
		    Next
		  #EndIf
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub LogThreadHandler(sender As Thread)
		  While mRunning Or mLogQueue.Count > 0
		    Try
		      // Protect queue access
		      mLogQueueMutex.Enter
		      Var messagesToLog() As String
		      
		      // Retrieve multiple messages from the queue (batch processing)
		      For i As Integer = 0 To 49 // Process up to 50 messages at a time
		        If mLogQueue.Count > 0 Then
		          messagesToLog.Add(mLogQueue(0))
		          mLogQueue.RemoveAt(0)
		        Else
		          Exit
		        End If
		      Next
		      mLogQueueMutex.Leave
		      
		      // Write messages outside mutex to reduce lock time
		      If messagesToLog.Count > 0 Then
		        WriteToFile(messagesToLog)
		      End If
		      
		      // Sleep to prevent busy waiting
		      If messagesToLog.Count = 0 Then
		        sender.SleepCurrent(mThreadSleepDuration)
		      End If
		      
		    Catch e As RuntimeException
		      // Log any unexpected errors
		      System.DebugLog("Log4Xojo: Logging thread error - " + e.Message)
		      
		      // Prevent tight error loops
		      sender.SleepCurrent(mThreadSleepDuration)
		    End Try
		  Wend
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub RotateLogFile(currentLogFile As FolderItem)
		  Try
		    // Get the folder where the log file is stored
		    Var folder As FolderItem = currentLogFile.Parent
		    If folder = Nil Then
		      System.DebugLog("Log4Xojo: Log file folder does not exist.")
		      Return
		    End If
		    
		    // Get the base name and extension using GenerateLogFileName
		    Var baseName As String = mLogName + "_" + DateTime.Now.SQLDate // Same logic as GenerateLogFileName
		    Var extension As String = currentLogFile.Extension
		    If extension.Trim = "" Then
		      extension = "txt" // Default to .txt if no extension
		    End If
		    
		    // If we've reached the maximum number of backup files, delete the oldest one
		    Var oldestBackupFile As FolderItem = folder.Child(baseName + "_" + Str(mMaxBackupFiles) + "." + extension)
		    If oldestBackupFile.Exists Then
		      oldestBackupFile.Remove
		    End If
		    
		    // Shift existing backup files
		    For i As Integer = mMaxBackupFiles - 1 DownTo 1
		      Var oldLogFile As FolderItem = folder.Child(baseName + "_" + Str(i) + "." + extension)
		      Var newLogFile As FolderItem = folder.Child(baseName + "_" + Str(i+1) + "." + extension)
		      
		      If oldLogFile.Exists Then
		        oldLogFile.Name = newLogFile.Name
		      End If
		    Next
		    
		    // Rename the current log file to the first backup
		    Var firstBackupFile As FolderItem = folder.Child(baseName + "_1." + extension)
		    currentLogFile.Name = firstBackupFile.Name
		    
		    // Create a new log file
		    Var newLogFile As New FolderItem(folder.Child(GenerateLogFileName()).NativePath, FolderItem.PathModes.Native)
		    Var out As TextOutputStream = TextOutputStream.Create(newLogFile)
		    out.Close
		    
		  Catch e As IOException
		    // Handle file rotation errors
		    System.DebugLog("Log4Xojo: Unable to rotate log file - " + e.Message)
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetLogDestinations(ParamArray destinations As LogDestination)
		  // Clear existing destinations
		  mLogDestinations.RemoveAll
		  
		  // Add the provided destinations
		  For Each destination As LogDestination In destinations
		    mLogDestinations.Add(destination)
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetLogFilePath(baseLocation As FolderItem)
		  If baseLocation = Nil Or Not baseLocation.Exists Then
		    Raise New InvalidArgumentException("Base location is invalid or does not exist.")
		  End If
		  
		  // Ensure the folder is writable
		  If Not baseLocation.IsWriteable Then
		    Raise New InvalidArgumentException("Base location is not writable.")
		  End If
		  
		  // Append the log name and current date to the base location to create the full file path
		  mLogFilePath = baseLocation.Child(GenerateLogFileName()).NativePath
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetLogLevel(level As LogLevel)
		  mCurrentLogLevel = level
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetMaxBackupFiles(max As Integer)
		  mMaxBackupFiles = max
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetMaxLogFileSize(sizeInBytes As Integer)
		  mMaxLogFileSize = sizeInBytes
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SetThreadSleepDuration(duration As Integer)
		  mThreadSleepDuration = duration
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub StopLogging()
		  // Allow the thread to continue processing the queue
		  If mLogThread <> Nil Then
		    Var startTime As Double = System.Microseconds
		    Const TimeoutMicroseconds = 5000000 // 5 seconds
		    
		    While mLogQueue.Count > 0 And System.Microseconds - startTime < TimeoutMicroseconds
		      // Sleep to allow the thread to process the queue
		      mLogThread.SleepCurrent(mThreadSleepDuration)
		    Wend
		    
		    // If the queue is still not empty, log a warning
		    If mLogQueue.Count > 0 Then
		      System.DebugLog("Log4Xojo: Timeout waiting for log queue to clear")
		    End If
		  End If
		  
		  // Now signal the thread to stop
		  mRunning = False
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function StringValue(e As LogLevel) As String
		  Select Case e
		  Case LogLevel.Debug
		    Return "DEBUG"
		  Case LogLevel.Info
		    Return "INFO"
		  Case LogLevel.Warning
		    Return "WARNING"
		  Case LogLevel.Error
		    Return "ERROR"
		  Case LogLevel.Critical
		    Return "CRITICAL"
		  Else
		    Return "UNKNOWN"
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function SystemLogLevelFromLogLevel(level As LogLevel) As Integer
		  Select Case level
		  Case LogLevel.Debug
		    Return System.LogLevelDebug
		  Case LogLevel.Info
		    Return System.LogLevelInformation
		  Case LogLevel.Warning
		    Return System.LogLevelWarning
		  Case LogLevel.Error
		    Return System.LogLevelError
		  Case LogLevel.Critical
		    Return System.LogLevelCritical
		  Else
		    Return System.LogLevelInformation
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub WriteToFile(messages() As String)
		  If mLogFilePath = "" Then
		    mLogFilePath = SpecialFolder.Documents.Child(GenerateLogFileName()).NativePath
		  End If
		  
		  Try
		    // Create a FolderItem from the path
		    Var logFile As New FolderItem(mLogFilePath, FolderItem.PathModes.Native)
		    
		    // Check and manage file size if needed
		    If logFile.Exists And mMaxLogFileSize > 0 Then
		      If logFile.Length >= mMaxLogFileSize Then
		        RotateLogFile(logFile)
		      End If
		    End If
		    
		    // Open the file for appending
		    Var out As TextOutputStream
		    out = TextOutputStream.Open(logFile)
		    
		    // Write all messages
		    For Each message As String In messages
		      out.WriteLine(message)
		    Next
		    
		    // Close the file
		    out.Close
		    
		  Catch e As IOException
		    // Add the messages back to the queue for retry
		    mLogQueueMutex.Enter
		    Try
		      For Each message As String In messages
		        mLogQueue.Add(message)
		      Next
		    Finally
		      mLogQueueMutex.Leave
		    End Try
		    
		    System.DebugLog("Log4Xojo: Unable to write to log file - " + e.Message)
		  Catch e As RuntimeException
		    System.DebugLog("Log4Xojo: Unexpected error writing log file - " + e.Message)
		  End Try
		End Sub
	#tag EndMethod


	#tag Note, Name = How to use Log4Xojo
		Official GitHub repo: https://github.com/xojo/log4xojo
		Blog: https://blog.xojo.com/2024/11/26/log4xojo-a-more-powerful-way-to-manage-your-app-logging/
		
		
		# 1. Monitoring Application Performance in Production
		In a production environment, it’s essential to keep track of your application’s behavior without impacting performance. With Log4Xojo, you can:
		
		Log important application events (e.g., user activity, API calls).
		Use file logging to store these logs persistently for later analysis.
		Filter logs by severity to avoid unnecessary noise (e.g., only warnings, errors, and critical issues).
		
		Example:
		Var l4x As New Log4Xojo("ProductionLog")
		l4x.SetLogDestinations(Log4Xojo.LogDestination.FileLog)
		l4x.SetLogLevel(Log4Xojo.LogLevel.Warning)
		 
		// Log application events
		l4x.Log("User logged in", Log4Xojo.LogLevel.Info) // Ignored (below warning level)
		l4x.Log("Database connection failed", Log4Xojo.LogLevel.Error) // Logged
		l4x.Log("Critical: Payment gateway unreachable", Log4Xojo.LogLevel.Critical) // Logged
		Outcome: Only warnings, errors, and critical messages are logged to a file for postmortem analysis without overwhelming the log with lower-priority messages.
		
		# 2. Creating a Diagnostic Tool for End Users
		When troubleshooting issues reported by end users, having detailed logs can be invaluable. With Log4Xojo, you can:
		
		Log messages to a file on the user’s machine.
		Include optional location tags to pinpoint where issues occur in your code.
		Use log rotation to prevent log files from consuming too much disk space.
		
		Example:
		Var l4x As New Log4Xojo("UserDiagnostics")
		l4x.SetLogDestinations(Log4Xojo.LogDestination.FileLog)
		l4x.SetLogFilePath(SpecialFolder.Documents)
		l4x.SetMaxLogFileSize(1 * 1024 * 1024) // 1 MB
		l4x.SetMaxBackupFiles(3)
		 
		// Log diagnostic information
		l4x.Log("Application launched", Log4Xojo.LogLevel.Info, CurrentMethodName)
		l4x.Log("Error: File not found", Log4Xojo.LogLevel.Error, "FileManager.LoadFile")
		l4x.Log("User clicked 'Submit'", Log4Xojo.LogLevel.Debug, "MainWindow.HandleSubmit")
		Outcome: You can ask users to send the log files stored in their Documents folder for review, helping you quickly diagnose and fix issues.
		
		# 3. Tracking User Activity in Enterprise Applications
		In enterprise applications, logging user activity is often a requirement for auditing or compliance purposes. With Log4Xojo, you can:
		
		Use multi-destination logging to send activity logs to both the system logs and a central log file.
		Include relevant context for each log entry (e.g., user ID, method).
		
		Example:
		Var l4x As New Log4Xojo("AuditLog")
		l4x.SetLogDestinations(Log4Xojo.LogDestination.SystemLog, Log4Xojo.LogDestination.FileLog)
		l4x.SetLogFilePath(SpecialFolder.Documents)
		 
		// Log user activity
		Var userID As String = "User123"
		l4x.Log(userID + " logged in", Log4Xojo.LogLevel.Info, "AuthManager.Login")
		l4x.Log(userID + " updated profile", Log4Xojo.LogLevel.Info, "ProfileManager.UpdateProfile")
		l4x.Log(userID + " attempted unauthorized access", Log4Xojo.LogLevel.Warning, "SecurityManager.CheckPermissions")
		Outcome: Both system logs and a persistent file log are updated with the user’s activities, ensuring compliance and easy traceability.
		
		# 4. Handling Errors and Crashes Gracefully
		When an application crashes, logs are often the only way to understand what went wrong. Log4Xojo can:
		
		Capture error and critical logs leading up to a crash.
		Rotate logs to avoid losing older, relevant logs.
		Save logs to a file for recovery after a crash.
		
		Example:
		Var l4x As New Log4Xojo("CrashLogs")
		l4x.SetLogDestinations(Log4Xojo.LogDestination.FileLog)
		l4x.SetMaxBackupFiles(5)
		l4x.SetMaxLogFileSize(1 * 1024 * 1024) // 1 MB
		 
		Try
		  // Simulate application logic
		  Raise New RuntimeException("Simulated crash")
		Catch e As RuntimeException
		  l4x.Log("Critical error: " + e.Message, Log4Xojo.LogLevel.Critical, CurrentMethodName)
		End Try
		Outcome: The log files can be used to investigate the cause of the crash.
		
	#tag EndNote


	#tag Property, Flags = &h21
		Private mCurrentLogLevel As LogLevel
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogDestinations() As LogDestination
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogFilePath As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogName As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogQueue() As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogQueueMutex As Mutex
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogThread As Thread
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mMaxBackupFiles As Integer = 10
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mMaxLogFileSize As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mRunning As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mThreadSleepDuration As Integer = 100
	#tag EndProperty


	#tag Constant, Name = MaxQueueSize, Type = Double, Dynamic = False, Default = \"10000", Scope = Public, Description = 4D6178696D756D206D6573736167657320696E20746865207175657565
	#tag EndConstant


	#tag Enum, Name = LogDestination, Type = Integer, Flags = &h0
		DebugLog
		  SystemLog
		  FileLog
		All
	#tag EndEnum

	#tag Enum, Name = LogLevel, Type = Integer, Flags = &h0
		Debug
		  Info
		  Warning
		  Error
		Critical
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
