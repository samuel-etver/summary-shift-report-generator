const srcFilesFolderName = "src"
const templateFileName = "template.xlsx"
const departmentsKeys = "ТЭСЦ 2; ТЭСЦ 4; ТЭСЦ 8; ТЭСЦ 9"
const departmentsTitles = "ТЭСЦ-2; ТЭСЦ-4; ТЭСЦ-8; ТЭСЦ-9"

public appPath
public srcFiles(1000)
public srcFilesCount
public srcFilesFolder
public dstFileName
public objFS
public departmentsKeysArr
public departmentsTitlesArr
public reports(100)
public reportsCount

reportsCount = 0
appPath = Replace(wscript.ScriptFullName, wscript.ScriptName, "")
srcFilesFolder = appPath & srcFilesFolderName
set objFS = CreateObject("Scripting.FileSystemObject")
departmentsKeysArr = Split(departmentsKeys, ";")
for i = LBound(departmentsKeysArr) to UBound(departmentsKeysArr)
  departmentsKeysArr(i) = Trim(departmentsKeysArr(i))
next
departmentsTitlesArr = Split(departmentsTitles, ";")
for i = LBound(departmentsTitlesArr) to UBound(departmentsTitlesArr)
  departmentsTitlesArr(i) = Trim(departmentsTitlesArr(i))
next 

BuildSrcFilesList()
ParseSrcFiles()
GenerateDstFileName()
CopyTemplate()
GenerateReport()


sub PrintLn(txt)
  wscript.echo txt
end sub

sub BuildSrcFilesList()
  dim objFolder
  dim objFiles
  dim objOneFile
  
  srcFilesCount = 0
  if not objFS.FolderExists(srcFilesFolder) then
    exit sub
  end if
  
  set objFolder = objFS.GetFolder(srcFilesFolder)
  set objFiles = objFolder.Files
  for each objOneFile in objFiles
    if objFS.FileExists(objOneFile) then
      srcFiles(srcFilesCount) = objOneFile.Name
      srcFilesCount = srcFilesCount + 1
	end if
  next
end sub


sub GenerateDstFileName()
  dim dt
  dim shift
  dim pos1
  dim pos2
  
  dt = "X"
  shift = "X"
  if reportsCount > 0 then
    dt = ClearCellText(reports(0).StartDate)
    pos1 = InStr(dt, ".")
    if pos1 > 0 then
      pos2 = InStr(pos1 + 1, dt, ".")
      if pos2 then
        dt = Left(dt, pos2 - 1)
      end if  
      dt = Replace(dt, ".", " ")
    end if

    shift = ClearCellText(reports(0).Shift)  
  end if

    
  
  dstFileName = "Рапорт СПА за " & dt & " смена " & shift & ".xlsx"
end sub


sub CopyTemplate()  
  dim templateFile
  dim dstFile
  templateFile = appPath & templateFileName
  dstFile = appPath & dstFileName
  objFS.CopyFile templateFile, dstFile, True
end sub


sub ParseSrcFiles()
  dim I  
  dim srcFileName
  dim objWord
  dim tablesCount
  dim objDoc
  dim objShiftTable
  dim objTaskTable
  dim objReport
  dim objTask
  dim row
  dim rowsCount
  dim firstTaskRow
  dim tasksCount
  dim taskI
  dim txt
  dim ok
  dim departmentIndex
  
  reportsCount = 0
  for I = 1 to srcFilesCount
    do
      fileName = srcFiles(I - 1)
      if objWord = Empty then
        set objWord = CreateObject("Word.Application")
      end if
      objWord.Visible = False
      set objDoc = objWord.Documents.Open(srcFilesFolder & "\" & fileName, True)
      tablesCount = objDoc.tables.Count
      set objReport = new DepartmentReport
      
      departmentIndex = GetIndexOfDepartment(objDoc)
      if (departmentIndex < 0) then
        println("Файл (" & fileName & ") из неизвестного цеха!")
        exit do
      end if

      if tablesCount >= 2 then
        set objShiftTable = objDoc.Tables(2)
        with objReport
          .Department = departmentsTitlesArr(departmentIndex)
          .Shift = ExtractCellText(objShiftTable.Cell(1, 2).Range.Text)
          .StartDate = ExtractCellText(objShiftTable.Cell(2, 2).Range.Text)
          .StartTime = ExtractCellText(objShiftTable.Cell(3, 2).Range.Text)
          .Person = ExtractCellText(objShiftTable.Cell(4, 2).Range.Text)
        end with
      end if
        
      if tablesCount >= 3 then
        set objTaskTable = objDoc.Tables(3)
        rowsCount = objTaskTable.Rows.Count
        firstTaskRow = 3
        tasksCount = rowsCount - firstTaskRow + 1
        for taskI = 0 to tasksCount - 1
          set objTask = new JobTask
          row = firstTaskRow + taskI
          with objTask
          .StartTime = ExtractCellText(objTaskTable.Cell(row, 2).Range.Text)
          .EndTime = ExtractCellText(objTaskTable.Cell(row, 3).Range.Text)
          .Aggreg = ExtractCellText(objTaskTable.Cell(row, 4).Range.Text)
          .FailureDescription = ExtractCellText(objTaskTable.Cell(row, 5).Range.Text)
          .WorkDescription = ExtractCellText(objTaskTable.Cell(row, 6).Range.Text)
          ok = (Len(ClearCellText(.StartTime)) > 0) _
            or (Len(ClearCellText(.EndTime)) > 0) _
            or (Len(ClearCellText(.Aggreg)) > 0) _
            or (Len(ClearCellText(.FailureDescription)) > 0) _
            or (Len(ClearCellText(.WorkDescription)) > 0)
          end with
          if ok then
          with objReport
            set .Tasks(.TaskCount) = objTask
            .TaskCount = .TaskCount + 1
          end with	
          end if	
        next 
      end if
      objDoc.Close
      set reports(reportsCount) = objReport
      reportsCount = reportsCount + 1
    loop while False		
  next
  
  if objWord <> Empty then
    objWord.Quit
  end if
end sub

function ClearCellText(txt)
  ClearCellText = Trim(Replace(Replace(txt, Chr(7), ""), Chr(13), ""))
end function

function ExtractCellText(txt) 
  ExtractCellText = Replace(txt, Chr(7), "")
end function

function GetIndexOfDepartment(doc) 
  dim index
  dim i
  dim j
  dim k
  dim keys
  dim sentencesCount
  dim sentence
  dim pos
  dim found
  
  index = -1
  
  for i = LBound(departmentsKeysArr) to UBound(departmentsKeysArr)
    keys = Split(UCase(departmentsKeysArr(i)))
	sentencesCount = doc.Sentences.Count
	if sentencesCount > 7 then
	  sentencesCount = 7
	end if
	
	for j = 1 to sentencesCount 
	  sentence = UCase(doc.Sentences(j))
	  pos = 0
	  for k = LBound(keys) to UBound(keys)
	    pos = InStr(sentence, keys(k))
		if pos < 1 then exit for
		sentence = Mid(sentence, pos)
	  next
	  if pos > 0 then
	    index = i
		exit for
	  end if
	next 
	
	if index >= 0 then exit for
  next  
  
  GetIndexOfDepartment = index
end function


sub GenerateReport()  
  const summaryShiftTableFirstRow = 1
  const departmentTableFirstRow = 4
  const departmentTableLastRow =  9 
  dim objExcel
  dim objWb
  dim objSh
  dim i  
  dim j
  dim k
  dim row
  dim col
  dim index
  dim report
  dim task
  
  set objExcel = CreateObject("Excel.Application")
  objExcel.Visible = True
  set objWb = objExcel.Workbooks.Open(appPath & dstFileName)
  set objSh = objWb.Sheets(1)
  
  row = summaryShiftTableFirstRow
  col = 4
  objSh.Cells(row, col).Value = GetSummaryShift()
  objSh.Cells(row + 1, col).Value = GetSummaryStartDate()
  objSh.Cells(row + 2, col).Value = GetSummaryStartTime()
  
  row = 10

  for k = LBound(departmentsTitlesArr) to UBound(departmentsKeysArr)
    for i = 0 to reportsCount - 1    
      do
        set report = reports(i)
        if report.Department <> departmentsTitlesArr(k) then
          exit do
        end if
        objSh.Rows(CStr(departmentTableFirstRow) & ":" & CStr(departmentTableLastRow)).Copy()
        objSh.Rows(row).PasteSpecial()
        
        objSh.Cells(row, 1).Value = report.Department
        objSh.Cells(row + 1, 4).Value = report.Person
        row = row + 5
        if report.TaskCount = 0 then
          objSh.Rows(row).Delete()
        end if
        for j = 0 to report.TaskCount - 1
          objSh.Rows(departmentTableLastRow).Copy
          objSh.Rows(row).PasteSpecial()
          set task = report.Tasks(j)  
          with task 
            objSh.Cells(row, 1) = .StartTime
            objSh.Cells(row, 2) = .EndTime
            objSh.Cells(row, 3) = .Aggreg
            objSh.Cells(row, 4) = .FailureDescription
            objSh.Cells(row, 5) = .WorkDescription
            row = row + 1
          end with
        next
      loop while False  
    next
  next
  
  objSh.Rows(CStr(departmentTableFirstRow) & ":" & CStr(departmentTableLastRow)).Delete()  
  objSh.Cells(1,1).Select()
  
  objWb.Save
  
  set objSh = Nothing
  set objWb = Nothing  
  set objExcel = Nothing
end sub

function GetSummaryShift()
  dim txt
  if reportsCount > 0 then
    txt = reports(0).Shift
  else
    txt = ""
  end if  
  GetSummaryShift = txt
end function

function GetSummaryStartDate()
  dim txt
  if reportsCount > 0 then
    txt = reports(0).StartDate
  else
    txt = ""
  end if
  GetSummaryStartDate = txt  
end function

function GetSummaryStartTime()
  dim txt
  if reportsCount > 0 then
    txt = reports(0).StartTime
  else
    txt = ""
  end if
  GetSummaryStartTime = txt
 end function


class DepartmentReport
  public Department
  public Shift
  public StartDate
  public StartTime
  public Person
  public Tasks(100)
  public TaskCount
  
  private sub Class_Initialize()
    me.TaskCount = 0
	me.Department = ""
	me.Shift = ""
	me.StartDate = ""
	me.StartTime = ""
	me.Person = ""
  end sub
end class

class JobTask
	public StartTime
	public EndTime
	public Aggreg
	public FailureDescription
	public WorkDescription
end class
