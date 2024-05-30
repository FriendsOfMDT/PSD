Function Get-DemoTyp73{
    (Get-CimInstance -ClassName win32_computersystem).Model
}