@echo off
setlocal
setlocal enabledelayedexpansion

REM Пути к папкам для мониторинга
set "folders_to_monitor=C:\2 C:\3"

REM Путь к папке для резервных копий
set "backup_folder=C:\backup"

REM Файл для временного хранения состояния файлов
set "state_file=%TEMP%\file_monitor_state.txt"
set "temp_file=%TEMP%\temp_file.txt"

:monitor_folders
REM Очистим файл состояния перед началом мониторинга
echo. > "%temp_file%"
for %%f in (%folders_to_monitor%) do ( 
    for /f %%a in ('dir /s /b /a-d "%%f"') do (
        call :process_file "%%a"
    )
)
rem type "%temp_file%"
copy /Y "%temp_file%" "%state_file%" > nul
echo. > "%temp_file%"    
timeout /t 15 >nul
goto monitor_folders

:process_file
set "file=%~1"
set "current_hash=Unknown"
REM Получаем текущую хэш-сумму файла с использованием Powershell
for /f "skip=1 tokens=*" %%H in ('certutil -hashfile "%file%" MD5 ^| findstr /r /v "^$"') do (
    set "current_hash=%%H"
    goto :continue
)
:continue
REM Считываем содержимое файла состояния, если он существует
if exist "%state_file%" (
    set "found=false"
    for /f "tokens=1,* delims==" %%i in ('type "%state_file%"') do (
        if "%%i" neq " " (
            if "%%j" equ "!file!" (
                echo !file! was found
                set "found=true"
                if "%%i" neq "!current_hash!" (
                    echo File "!file!" has been modified.
                    echo %current_hash%=!file!>> "%temp_file%"
                    call :backup_file "!file!"     
                ) else (
                    rem Иначе просто переносим текущую строку во временный файл
                    echo %%i=%%j>> "%temp_file%"
                )     
            )
        )
    )
    if "%found%"=="false" (
        echo Not found: !file!
        echo %current_hash%=!file!>> "%temp_file%"
        rem echo.>> "%temp_file%"
    )
) else (
    echo "%current_hash%=%file%">> "%temp_file%"
)
exit /b

:backup_file
set "file=%~1"
echo Backing up file: %file%

REM Определение текущей даты и времени
for /f "tokens=1-3 delims=. " %%i in ('date /t') do (
    set "day=%%i"
    set "month=%%j"
    set "year=%%k"
)
        
for /f "tokens=1-2 delims=: " %%i in ('time /t') do (
    set "hour=%%i"
    set "minute=%%j"
)
        
REM Создание папки для резервного копирования                            
if not exist "%backup_folder%\Backup_%year%-%month%-%day%_%hour%-%minute%" (
    mkdir "%backup_folder%\Backup_%year%-%month%-%day%_%hour%-%minute%"
)
       
REM Проверка успешного создания папки
if not exist "%backup_folder%\Backup_%year%-%month%-%day%_%hour%-%minute%" (
    echo Не удалось создать папку для резервного копирования.
    exit /b
)
        
xcopy "%file%" "%backup_folder%\Backup_%year%-%month%-%day%_%hour%-%minute%\" /E /C /H /Y  
goto :send_email        
        
:send_email
set "subject=Changed file"
set "body=File %file% was changed"
echo Sending email with subject: %subject% and body: %body% 
call mailsend1.19.exe -smtp smtp.mail.ru -port 465 -ssl -auth -user backup_status@mail.ru -pass tTp6dAeQuFDfY2wPLHY5 -t backup_status@mail.ru -f backup_status@mail.ru -name "Anastasiia Kardash" -cs 1251 -sub "%subject%" -M "%body%"                                                              
exit /b
