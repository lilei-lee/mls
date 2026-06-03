' VBS Calculator - pure VBScript, double-click to run
' Supports: + - * / ( ) and decimals  |  Example: (2+3)*4-6/2

Dim expr
Do
    expr = InputBox("Enter expression:" & vbCrLf & vbCrLf & _
        "Supports: + - * / ( ) and decimals" & vbCrLf & _
        "Example: (2+3)*4-6/2" & vbCrLf & vbCrLf & _
        "Click Cancel or leave empty to exit", "VBS Calculator", "")
    If IsEmpty(expr) Or expr = "" Then Exit Do
    expr = Replace(expr, " ", "")
    If expr = "" Then Exit Do

    On Error Resume Next
    Dim result
    result = EvalExpr(expr)
    If Err.Number <> 0 Then
        MsgBox "Expression error, please check", vbCritical, "Error"
        Err.Clear
    Else
        MsgBox expr & " = " & CStr(result), vbInformation, "Result"
    End If
    On Error Goto 0
Loop

'============================================
' Recursive descent parser
'============================================

Dim pos, tokens, tokCount

Function EvalExpr(s)
    Tokenize s
    pos = 0
    EvalExpr = ParseAddSub
End Function

Sub Tokenize(s)
    Dim i, c, num, n
    n = Len(s)
    ReDim tokens(n - 1)
    tokCount = 0
    i = 1
    Do While i <= n
        c = Mid(s, i, 1)
        If c = "+" Or c = "-" Or c = "*" Or c = "/" Or c = "(" Or c = ")" Then
            tokens(tokCount) = c
            tokCount = tokCount + 1
            i = i + 1
        ElseIf IsNumeric(c) Or c = "." Then
            num = ""
            Do While i <= n And (IsNumeric(Mid(s,i,1)) Or Mid(s,i,1) = ".")
                num = num & Mid(s, i, 1)
                i = i + 1
            Loop
            tokens(tokCount) = num
            tokCount = tokCount + 1
        Else
            Err.Raise 1, , "Invalid char: " & c
            Exit Sub
        End If
    Loop
End Sub

Function Peek
    If pos < tokCount Then Peek = tokens(pos) Else Peek = ""
End Function

Function NextToken
    If pos < tokCount Then
        NextToken = tokens(pos)
        pos = pos + 1
    Else
        NextToken = ""
    End If
End Function

' addition/subtraction (lowest precedence)
Function ParseAddSub
    Dim val, op
    val = ParseMulDiv
    Do While Peek = "+" Or Peek = "-"
        op = NextToken
        If op = "+" Then
            val = val + ParseMulDiv
        Else
            val = val - ParseMulDiv
        End If
    Loop
    ParseAddSub = val
End Function

' multiplication/division (high precedence)
Function ParseMulDiv
    Dim val, op
    val = ParseAtom
    Do While Peek = "*" Or Peek = "/"
        op = NextToken
        If op = "*" Then
            val = val * ParseAtom
        Else
            Dim divisor
            divisor = ParseAtom
            If divisor = 0 Then
                Err.Raise 2, , "Division by zero"
                Exit Function
            End If
            val = val / divisor
        End If
    Loop
    ParseMulDiv = val
End Function

' atom: number or parenthesized expression
Function ParseAtom
    Dim tk
    tk = Peek
    If tk = "" Then
        Err.Raise 3, , "Incomplete expression"
        Exit Function
    End If
    If tk = "(" Then
        NextToken  ' eat (
        ParseAtom = ParseAddSub
        If Peek <> ")" Then
            Err.Raise 4, , "Missing )"
            Exit Function
        End If
        NextToken  ' eat )
    ElseIf tk = "-" Then
        NextToken  ' eat -
        ParseAtom = -ParseAtom  ' unary minus
    ElseIf IsNumeric(tk) Then
        ParseAtom = CDbl(NextToken)
    Else
        Err.Raise 5, , "Unexpected: " & tk
    End If
End Function
