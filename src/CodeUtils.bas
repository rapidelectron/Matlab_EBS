Attribute VB_Name = "CodeUtils"
Public Sub ExportModules()
    'Source: https://www.rondebruin.nl/win/s9/win002.htm
    
    Dim bExport As Boolean
    Dim wkbSource As Excel.Workbook
    Dim exportPath As String
    Dim filenamee As String
    Dim comp As VBIDE.VBComponent

    'The code modules will be exported in <WORKSHEET_FOLDER>/src
    
    'Test if directory exists
    If StrComp(VBA.FileSystem.dir(GetExportFolderPath(), vbDirectory), VBA.Constants.vbNullString) = 0 Then
        Exit Sub
    End If
    
    'Delete all existing files in the folder
    On Error Resume Next
    Call Kill(GetExportFolderPath() & "\*.*")
    On Error GoTo 0

    Set wkbSource = ThisWorkbook
    
    If wkbSource.VBProject.Protection = 1 Then
    MsgBox "The VBA in this workbook is protected," & _
        "not possible to export the code"
    Exit Sub
    End If
    
    exportPath = GetExportFolderPath & "\"
    
    For Each comp In wkbSource.VBProject.VBComponents
        
        bExport = True
        filenamee = comp.name

        'Concatenate the correct filename for export.
        Select Case comp.Type
            Case vbext_ct_ClassModule
                filenamee = filenamee & ".cls"
            Case vbext_ct_MSForm
                filenamee = filenamee & ".frm"
            Case vbext_ct_StdModule
                filenamee = filenamee & ".bas"
            Case vbext_ct_Document
                If StrComp(comp.name, "Planning") = 0 Or _
                    StrComp(comp.name, "ThisWorkbook") = 0 Or _
                    StrComp(comp.name, "TaskSheetTemplate") = 0 Or _
                    StrComp(comp.name, "EbsSheetTemplate") = 0 Or _
                    StrComp(comp.name, "Settings") = 0 Then
                    bExport = True
                    
                    filenamee = filenamee & ".cls"
                Else
                    bExport = False
                End If
        End Select
        
        If bExport Then
            'Export the component to a text file.
            Call comp.Export(exportPath & filenamee)
        End If
   
    Next comp
End Sub



Function GetExportFolderPath() As String
    GetExportFolderPath = ThisWorkbook.Path() & "\src"
End Function