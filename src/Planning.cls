VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Planning"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
'  This macro collection lets you organize your tasks and schedules
'  for you with the evidence based design (EBS) approach by Joel Spolsky.
'
'  Copyright (C) 2019  Christian Weihsbach
'  This program is free software; you can redistribute it and/or modify
'  it under the terms of the GNU General Public License as published by
'  the Free Software Foundation; either version 3 of the License, or
'  (at your option) any later version.
'  This program is distributed in the hope that it will be useful,
'  but WITHOUT ANY WARRANTY; without even the implied warranty of
'  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'  GNU General Public License for more details.
'  You should have received a copy of the GNU General Public License
'  along with this program; if not, write to the Free Software Foundation,
'  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
'
'  Christian Weihsbach, weihsbach.c@gmail.com

Option Explicit

'A special modified selection which can be just the 'normal' excel Selection range or an extended selection which
'includes all the cells of column in the task list which have the same value (multiple selection)
Public lastSpecialSelection As Range

Enum UserEstimateStatus
    ceInvalid = 0
    ceValidHours = 1
    ceValidDate = 2
End Enum

Enum CumulativeMode
    ceInvalid = 0
    ceCumulative = 1
    ceSingle = 2
End Enum



Private Sub Worksheet_SelectionChange(ByVal Target As Range)
    'Run a catched call to the main selection handler method in this sheet
    Utils.RunTryCatchedCall f:="HandleSelectionChanges", obj:=Planning, arg1:=Target, screenUpdating:=False
End Sub



Private Sub Worksheet_Change(ByVal Target As Range)
    'Run a catched call to the main value handler method in this sheet
    Call Utils.RunTryCatchedCall("HandleChanges", Planning, Target)
End Sub



Private Sub Worksheet_FollowHyperlink(ByVal Target As hyperlink)
    'Run a catched call to the hyperlink handler method in this sheet
    Utils.RunTryCatchedCall f:="PlanningUtils.FollowTaskSheetLink", arg1:=Target
End Sub



Sub UI_AddNewTask()
    'Add a new task
    Utils.RunTryCatchedCall f:="PlanningUtils.AddNewTask", enableEvt:=False, screenUpdating:=False
End Sub



Sub UI_CopyTask()
    'Copy a task. Do make sure the user's current selection will point to the copied task after creating it. To do so create the new hash here directly
    'and search for it afterwards
    
    Dim copiedHash As String
    copiedHash = GetTaskHash()
    
    If SanityChecks.CheckHash(copiedHash) Then
        Dim newHash As String
        newHash = CreateHashString("t")
        'Call this function with events to copy the task data from worksheet to task sheet immediately
        'Only call with disabled events to not mix up the cell validation values
        Utils.RunTryCatchedCall f:="PlanningUtils.CopyTask", arg1:=copiedHash, arg2:=newHash, enableEvt:=False, screenUpdating:=False
        
        'Select the new task
        Dim copiedCell As Range
        Set copiedCell = PlanningUtils.IntersectHashAndListColumn(newHash, Constants.TASK_NAME_HEADER)
        
        If Not copiedCell Is Nothing Then
            copiedCell.Select
        End If
    End If
End Sub



Sub UI_DeleteSelectedTask()
    'Delete the entire task (cannot be undone). Delete the task sheet (named by tHash) and the task row entry in the planning sheet
    Utils.RunTryCatchedCall f:="PlanningUtils.DeleteSelectedTask", screenUpdating:=False
End Sub



Sub UI_EndAllTasks()
    'Stop tracking for all tasks (helps preventing errors with unconsistent data as not only the task that is actively tracking is stopped)
    Call Utils.RunTryCatchedCall("PlanningUtils.EndAllTasks")
End Sub



Sub UI_StartSelectedTask()
    'Track the selected task (add timestamp)
    Utils.RunTryCatchedCall f:="PlanningUtils.StartSelectedTask"
End Sub



Sub UI_AddFiveteenMinutesToSelectedTask()
    'Add start and end timestamp to a task so that 15 minutes of time are booked for that task.
    Dim hash As String
    'Get the hash of the selected task
    hash = GetTaskHash()
    
    If SanityChecks.CheckHash(hash) Then
        Utils.RunTryCatchedCall f:="TaskUtils.AddXHoursTime", arg1:=TaskUtils.GetTaskSheet(hash), arg2:=CDbl(0.25)
    End If
End Sub



Sub UI_AddZeroMinutesToSelectedTask()
    'Used to set a point of time to the task tracking data
    
    Dim hash As String
    'Get the hash of the selected task
    hash = GetTaskHash()
    
    If SanityChecks.CheckHash(hash) Then
        Utils.RunTryCatchedCall f:="TaskUtils.AddXHoursTime", arg1:=TaskUtils.GetTaskSheet(hash), arg2:=CDbl(0)
    End If
End Sub



Sub UI_ShiftTaskUp()
    'Shift task up in the planning list (increase priority). To see the effect the list has to be sorted for descending priority number.
    'Sorting is applied automatically when calling the function.
    
    Utils.RunTryCatchedCall f:="PlanningUtils.ShiftPrio", arg1:=ShiftDirection.ceShiftUp, arg2:=lastSpecialSelection, _
        enableEvt:=False, screenUpdating:=False
    'Since the shift prio command changes the selection with disabled events, handle the selection change manually afterwards.
    'Somehow this does not work when you handle the change inside the Shift prio call through 'RunTryCatchedCall'
    Call Planning.HandleSelectionChanges(Selection)
End Sub



Sub UI_ShiftTaskDown()
    'Shift task down in the planning list (increase priority). To see the effect the list has to be sorted for descending priority number.
    'Sorting is applied automatically when calling the function.
    
    Utils.RunTryCatchedCall f:="PlanningUtils.ShiftPrio", arg1:=ShiftDirection.ceShiftDown, arg2:=lastSpecialSelection, _
        enableEvt:=False, screenUpdating:=False
    'Since the shift prio command changes the selection with disabled events, handle the selection change manually afterwards.
    'Somehow this does not work when you handle the change inside the Shift prio call through 'RunTryCatchedCall'
    Call Planning.HandleSelectionChanges(Selection)
End Sub



Sub UI_GatherTasks()
    'Edit the priorities of all selected tasks (see multi selection with highlighted lines in task sheet) so that they are sticking together.
    'To see the effect the list has to be sorted for descending priority number.
    'Sorting is applied automatically when calling the function.
    
    Utils.RunTryCatchedCall f:="PlanningUtils.GatherTasks", arg1:=lastSpecialSelection, _
        enableEvt:=False, screenUpdating:=False
    'Since the gather tasks command changes the selection with disabled events, handle the selection change manually afterwards.
    'Somehow this does not work when you handle the change inside the gahter tasks call through 'RunTryCatchedCall'
    Call Planning.HandleSelectionChanges(Selection)
End Sub



Sub UI_RunEbs()
    'THE main feature. Run all the steps to get evidence based sheduling data and charts for every contributor.
    Utils.RunTryCatchedCall f:="EbsUtils.RunEbs"
End Sub



Sub UI_CollectTotalTimesSpent()
    'Read the task's data to get the total time a user spent working on it.
    Utils.RunTryCatchedCall f:="PlanningUtils.CollectTotalTimesSpent"
End Sub



Function HandleChanges(Target As Range)
    'Main cell value change handler. The function checks if a cell of the planning list object was edited. In addition some special
    'cells above the list are checked as well.
    'Handling changes differs from column to column. At first the column headers are read and then a specific handler is called.
    'For user-defined headers (e.g. tag headers with fixed prefix but variable suffix) the header is first normalized (set to its regex expression)
    
    Dim header As String
    header = Utils.GetListColumnHeader(Target) 'The header can only be fetched if a cell inside the list object is selected
    If Target.Count <> 1 Then
        'Currently only changes to one cell will be handled. Do only select single cells inside the table, otherwise deletion of values will fail.
        'To do: Call the steps below on every cell of the selection with for each loop and test.
        Exit Function
    End If

    If StrComp(header, "") = 0 Then
        'Use a fallback for special cells above ebs data columns of the table: Do additional checking of the cell above even when
        'reading the header fails (this is the case if the special cell above the list is selected)
        
        Dim regex As New RegExp
        regex.Global = True
        regex.Pattern = Constants.EBS_COLUMN_REGEX
        Dim bn As Range
        Set bn = Utils.GetBottomNeighbour(Target)
        
        'Test if the bottom neighbour of the selected cell is an ebs column.
        'Set the header so that the handler for the ebs column is called
        If regex.Test(bn.Value) Then
            Set Target = bn
            header = bn.Value
        Else
            Exit Function
        End If
    End If
    
    'Make tag names and ebs column names comparable to standard value (set regex expression as 'header')
    header = UnifyTagName(header)
    header = UnifyEbsColumnName(header)
    
    'Call the specific handler depending on the column header
    Select Case (header)
        Case TASK_NAME_HEADER
            Call ManageTaskNameChange(Target)
        Case TASK_PRIORITY_HEADER
            Call ManageTaskPriorityChange
        Case TASK_ESTIMATE_HEADER:
            Call ManageEstimateChange(Target)
        Case KANBAN_LIST_HEADER:
            Call ManageKanbanListChange(Target)
        Case COMMENT_HEADER:
            Call ManageCommentChange(Target)
        Case TAG_REGEX
            Call ManageTagChange(Target)
        Case EBS_COLUMN_REGEX
            Call ManageEbsColChange(Target)
        Case DUE_DATE_HEADER
            Call ManageDueDateChange(Target)
        Case CONTRIBUTOR_HEADER
            Call ManageContributorChange(Target)
        Case T_HASH_HEADER:
            Call ManageHashChange(Target)
    End Select
End Function



Function HandleSelectionChanges(Target As Range)
    'Main selection handler. The function checks if a cell of the planning list object was selected.
    'Currently only special cell highlighting is maintained with this feature:
    'Highlight multiple rows of the list if a selected value can be found in another row of the same column.
    'The special highlight is saved to a public variable to store it.
    
    Dim header As String
    header = Utils.GetListColumnHeader(Target)
    
    'Reset highlight of all cells (all special multi-selected cells)
    PlanningUtils.ResetHighlight
    
    If StrComp(header, "") = 0 Then
        Exit Function
    End If
    
    'Make tag names comparable with replacing their custom tag column header with their regex expression
    header = UnifyTagName(header)
    
    'Call highlighting for kanban list col, contributor col and tag cols
    Dim highlight As Range
    Select Case (header)
        Case Constants.TAG_REGEX, Constants.CONTRIBUTOR_HEADER, Constants.KANBAN_LIST_HEADER
            Set highlight = ManageHighlightableSelChange(Target)
    End Select
    
    'Store the special highlight selection (only the range of multiple equivalent values in the selected column are stored, not the full row range)
    If Not highlight Is Nothing Then
        Set lastSpecialSelection = highlight
    Else
        Set lastSpecialSelection = Target
    End If
    
    'Debug info
    'Debug.Print "Last savedSelection is: " + lastSpecialSelection.Address
End Function



Function UnifyTagName(header As String) As String
    'Replace the custom tag header (fixed prefix but variable suffix) with its regex expression
    Dim regex As New RegExp

    regex.Global = True
    regex.Pattern = Constants.TAG_REGEX
    
    If regex.Test(header) Then
        UnifyTagName = Constants.TAG_REGEX
    Else
        'Fall back to old header
        UnifyTagName = header
    End If
End Function



Function UnifyEbsColumnName(header As String) As String
    'Replace the ebs column name (propability and date/time setting stored in name) with its regex expression
    Dim regex As New RegExp

    regex.Global = True
    regex.Pattern = Constants.EBS_COLUMN_REGEX
    
    If regex.Test(header) Then
        UnifyEbsColumnName = Constants.EBS_COLUMN_REGEX
        Exit Function
    Else
        'If none of the above regex matches fall back to old value
        UnifyEbsColumnName = header
    End If
End Function


Function ManageTaskNameChange(changedCell As Range)
    'Manage the change of the task name. Set it to the task sheet
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If CheckHash(hash) Then
        Call TaskUtils.SetTaskName(TaskUtils.GetTaskSheet(hash), changedCell.Value)
    End If
End Function



Function ManageEstimateChange(changedCell As Range)
    'Manage the change of the user's estimate. Multiple things are done here.
    ' (1) Estimate is copied to task sheet
    ' (1.1) But prior to copying it it is check for its type and validity.
    ' (2) If the value is valid check if a date or a time h (double) value was passed
    ' (3) In case of an entered date the date is converted to time h (double) value with looking up events in the (outlook) user's calendar
    ' (4) The entered date value is then replaced with the time h equivalent calculated from 'Now'
    
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If CheckHash(hash) Then
        Dim enteredVal As Variant
        enteredVal = changedCell.Value
        
        Dim ues As UserEstimateStatus
        
        'Determine the status of the entered value
        If IsNumeric(enteredVal) Or IsDate(enteredVal) Then
            If 0 < CDbl(enteredVal) And CDbl(enteredVal) < 100 Then
                'A value less than 100 is allowed for entered hours (generally entered hours should not be larger than 16.0)
                ues = UserEstimateStatus.ceValidHours
            ElseIf CDbl(enteredVal) > CDbl(Now) Or enteredVal = CalendarUtils.GetStartOfDay(Now) Then
                'Entered date has to be later than 'NOW'. This does not apply, if the date without clock time is e.g. 16/07/2019 and 'NOW' is 16/07/2019 07:00.
                'It is assumed that the user sets the end of 16/07/2019 as time limit and not the beginning if no time is passed along
                ues = UserEstimateStatus.ceValidDate
            Else
                ues = UserEstimateStatus.ceInvalid
            End If
        Else
            'No numeric or date data: Val is not an estimate
            ues = UserEstimateStatus.ceInvalid
        End If
        
        Dim outputVal As Variant
        outputVal = enteredVal
        'Process entered value
        If ues = UserEstimateStatus.ceValidDate Then
            'User entered a date - calculate estimate
            Dim enteredDate As Date
            enteredDate = CDate(enteredVal)
            
            If (enteredDate = CalendarUtils.GetStartOfDay(enteredDate)) Then
                'If the user entered a date of a day e.g. 16/07/2019 w/o clock time then the end of the day will be taken as time limit
                enteredDate = CalendarUtils.GetEndOfDay(enteredDate)
            End If
            
            'Now convert date to hours
            Dim contributorCell As Range
            Set contributorCell = PlanningUtils.IntersectHashAndListColumn(hash, Constants.CONTRIBUTOR_HEADER)
                    
            Dim contributor As String
            If Not contributorCell Is Nothing Then
                contributor = contributorCell.Value
            Else
                contributor = ""
            End If
            
            'Read the calendar appointments (if any)
            Dim calItems As Outlook.Items
            Set calItems = CalendarUtils.GetCalItems(contributor, Constants.BUSY_AT_OPTIONAL_APPOINTMENTS)
                
            'Calc a mapped hour value: The free time in between all appointments and the given dates
            outputVal = CalendarUtils.MapDateToHours( _
                contributor, _
                calItems, _
                enteredDate, _
                Now, _
                SettingUtils.GetContributorApptOnOffset(contributor, ceOnset), _
                SettingUtils.GetContributorApptOnOffset(contributor, ceOffset))
            
            If outputVal > 0 Then
                ues = UserEstimateStatus.ceValidHours
            Else
                'It is not useful to set the estimate to zero. Especially it cannot be negative
                ues = UserEstimateStatus.ceInvalid
            End If
        End If
        
        'Adjust formatting of the planning sheet cell to display the enterd value correctly
        Select Case ues
            Case UserEstimateStatus.ceValidHours
                Call TaskUtils.SetEstimate(TaskUtils.GetTaskSheet(hash), CDbl(enteredVal))
                changedCell.Value = outputVal
                changedCell.NumberFormat = "0.00"
                
            Case UserEstimateStatus.ceInvalid
                'Value was malformed. Set placeholder to cells and append malformed val
                Dim invalidPlaceholder As String
                invalidPlaceholder = Constants.INVALID_ENTRY_PLACEHOLDER + CStr(enteredVal)
            
                changedCell.Value = invalidPlaceholder
                changedCell.NumberFormat = "General"
                Call TaskUtils.SetEstimate(TaskUtils.GetTaskSheet(hash), invalidPlaceholder)
        End Select
    End If
End Function



Function ManageTaskPriorityChange()
    'Sort the data column priority
    Call PlanningUtils.OrganizePrioColumn
End Function



Function ManageKanbanListChange(changedCell As Range)
    'Handle the 'status' change of a task.
    
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If Not CheckHash(hash) Then Exit Function
    
    'Set the value to the task sheet
    Call TaskUtils.SetKanbanList(TaskUtils.GetTaskSheet(hash), changedCell.Value)
                
    Dim finishedOnCell As Range
    Set finishedOnCell = PlanningUtils.IntersectHashAndListColumn(hash, Constants.TASK_FINISHED_ON_HEADER)
            
    Dim prioCell As Range
    Set prioCell = PlanningUtils.IntersectHashAndListColumn(hash, Constants.TASK_PRIORITY_HEADER)
    
    Select Case (changedCell.Value)
        Case Constants.KANBAN_LIST_DONE
            If PlanningUtils.IsTaskTracking(changedCell) Then
                Call PlanningUtils.EndAllTasks
            End If
            
            'When the task is changed to 'done' the end time stamp in the sheet can be set. It is set to the last
            'time the user tracked time for this task. If no time was tracked the time stamp is set to 'Now'
            Dim lastStamp As Double
            lastStamp = CDbl(TaskUtils.GetLastEndTimestamp(TaskUtils.GetTaskSheet(hash)))
                
            If lastStamp <> 0 Then
                finishedOnCell.Value = CDate(lastStamp)
            Else
                finishedOnCell.Value = CDate(Now)
            End If
                prioCell.Value = Constants.N_A
                
        Case Constants.KANBAN_LIST_IN_PROGRESS, Constants.KANBAN_LIST_TODO
            'The task is active again: Delete finished on date and set high priority to move up the task
            finishedOnCell.Value = Constants.N_A
            prioCell.Value = Constants.TASK_PRIO_INITIAL
    End Select
    
    'Sort the priority column
    PlanningUtils.OrganizePrioColumn
End Function



Function ManageHashChange(changedCell As Range)
    'To do: Prevent editing of the cells. (optional)
    'changedCell.Value = valueOnSelecting
    'MsgBox "Changing the HASH is not allowed. Value was reset."
End Function



Function ManageCommentChange(changedCell As Range)
    'Just copy the comment to the task sheet
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If CheckHash(hash) Then
        Call TaskUtils.SetComment(TaskUtils.GetTaskSheet(hash), changedCell.Value)
    End If
End Function



Function ManageTagChange(changedCell As Range)
    'If the user entered a new tag inside the tag column add the tag to the cell validation list (to make it selectable by dropdown).
    'Adding cell validation should prevent extensive creation of new tags - the user is informed if a 'new' tag is inserted which might be accidental
    Dim tagCol As Range
    Set tagCol = Utils.GetListColumn(PlanningUtils.GetPlanningSheet, Constants.TASK_LIST_NAME, changedCell, ceData)
    
    Call Utils.SetCellValuesForValidation(tagCol)
End Function



Function ManageEbsColChange(changedCell As Range)
    'Collect the data of task sheets ebs estimates (non-cumulative estimates of task self time) or
    'of ebs sheet estimates (cumulative estimates of task queue for a specific user)
    Call PlanningUtils.CollectEbsColData(changedCell)
End Function



Function ManageHighlightableSelChange(changedCell As Range) As Range
    'Set highlight to special multi-selected cells and return the highlighted range (column cells, no entire row selection)
    Set ManageHighlightableSelChange = PlanningUtils.SetMultiCellHighlight(changedCell)
End Function



Function ManageContributorChange(changedCell As Range, Optional setCellValidation As Boolean = True)
    'Mange the contributor change
    '
    'Input args:
    '   changedCell:            The cell a contributor's name got changed in
    '   setCellValueValidation: If true the data validation list will be updated. In some cases this leads to a fail of cell column validation. Therefore
    '                           updating the list can be prevented.
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If Not CheckHash(hash) Then Exit Function
    
    Call TaskUtils.SetContributor(TaskUtils.GetTaskSheet(hash), changedCell.Value)
    
    Dim contributorCells As Range
    Set contributorCells = PlanningUtils.GetTaskListColumn(Constants.CONTRIBUTOR_HEADER, ceData)
    
    'Debug info
    'Debug.Print contributorCells.Address
    
    'If no errors are expected update the data validation list
    If setCellValidation Then
        Call Utils.SetCellValuesForValidation(contributorCells)
    End If
    
    'If the contributor changes the database for estimates changes as well. Recalculate
    Dim sheet As Worksheet
    Set sheet = TaskUtils.GetTaskSheet(hash)
    Call TaskUtils.SetEbsEstimates(sheet, TaskUtils.GetEstimate(sheet))
End Function



Function ManageDueDateChange(changedCell As Range)
    'Copy the due date to the task sheet
    If Not IsDate(changedCell.Value) Then
        Exit Function
    End If
    
    Dim hash As String
    hash = GetTaskHash(changedCell)
    If CheckHash(hash) Then
        Call TaskUtils.SetDueDate(TaskUtils.GetTaskSheet(hash), CDate(changedCell.Value))
    End If
End Function