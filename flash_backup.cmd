@echo off
chcp 1251 > nul
setlocal

setlocal enabledelayedexpansion

rem Переменная для хранения буквы диска флэшки
set "flash_drive_letter="

rem Ищем съемный диск
for /f "tokens=*" %%a in ('wmic logicaldisk get Caption^,DriveType /value ^| findstr /c:"Caption=" /c:"DriveType="') do (
    rem Разделяем строку на пару "Caption" и "DriveType"
    for /f "tokens=1,* delims== " %%b in ("%%a") do (
        rem Проверяем, является ли диск съемным
        if "%%b"=="Caption" (
            set "drive_letter=%%c"
        ) else if "%%b"=="DriveType" (
            set "drive_type=%%c"
            rem Если диск съемный, обрабатываем его
            if "!drive_type!"=="2" (
                set "flash_drive_letter=!drive_letter!"
                goto :found_flash_drive
            )
        )
    )
)                        
:found_flash_drive
rem Проверяем тип файловой системы флэшки (если есть)
if defined flash_drive_letter (
    for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where "DeviceID='%flash_drive_letter%'" get FileSystem /value ^| find "="') do (
        set "file_system=%%F"
    )
) else (
    echo Флэш-накопитель не обнаружен.
    exit /b
)

echo Файловая система: %file_system%
echo.

rem Определение пути к флэш-накопителю
set "flash_drive_path=%flash_drive_letter%\"

rem Проверка наличия прав администратора
whoami /priv | find "SeBackupPrivilege" >nul && set "admin=1" || set "admin=0"

rem Определение типа интерфейса флэшки
set "usb_version=Unknown"
for /f "tokens=2 Delims== " %%V in ('wmic diskdrive where "mediatype='removable media'" get interfacetype /value ^| find "="') do (
    if "%%V" neq "USB 3.0" (
        set "usb_version=USB 2.0"
    ) else (
        set "usb_version=USB 3.0"
    )
)

echo Тип интерфейса: %usb_version%

echo.

REM Выводим сообщение с предложением выбора
echo Choose the script:
echo 1. Make a backup
echo 2. Delete old backups
set /p choice="Write a number: "

REM Проверяем выбор пользователя и запускаем соответствующий скрипт
if "%choice%"=="1" (
    call :run_script1
) else if "%choice%"=="2" (
    call :run_script2
) else (
    echo Incorrect input. Please, choose 1 or 2.
)

exit /b

:run_script1
echo Launching script 1...

set "free_space=Unknown"
rem Объём свободного места
for /f "tokens=3" %%a in ('dir /-c "%flash_drive_path%" ^| find "байт свободно"') do (
    set "free_space=%%a"
) 

set "check_file=C:\checkfile"

for /F %%A in ('dir /A:-D /-C /B "%check_file%" 2^>NUL') do (
    set "check_size=%%~zA"
)

for /f "tokens=2 delims== " %%a in ('wmic path Win32_PerfFormattedData_PerfOS_System get SystemUpTime /value ^| find "SystemUpTime"') do set "start_time=%%a"

xcopy "%check_file%" "%flash_drive_path%\" /C /Y          
        
for /f "tokens=2 delims== " %%a in ('wmic path Win32_PerfFormattedData_PerfOS_System get SystemUpTime /value ^| find "SystemUpTime"') do set "end_time=%%a"                                                                                    

set "time_diff=Unknown"
set /a "start_time_int=start_time"
set /a "end_time_int=end_time"
set /a "time_diff=end_time_int - start_time_int"
 
rem Расчет скорости копирования в мегабайтах в секунду
set /a "copy_speed_check=check_size/time_diff"
echo %copy_speed_check%
:input_path
rem Запрос пути к исходной папке для резервного копирования
set /p source_folder=Введите путь к исходной папке: 

rem Проверка существования папки
if not exist "%source_folder%" (
    echo Папка "%source_folder%" не существует. Попробуйте снова.
    goto input_path
)

rem Проверка размера файла
set "max_file_size_bytes=4294967295"

set "folder_size=Unknown"

for /r "%source_folder%" %%F in (*) do (
    set /a "folder_size+=%%~zF"
) 
   
if %folder_size% gtr %max_file_size_bytes% (
    if %file_system%=="FAT32" (
        echo Файл %source_folder% превышает максимально допустимый размер для FAT32.
        goto input_path
    )
) else (
    goto copy_file
)

:copy_file
if %folder_size% lss %free_space% (
    if "%admin%"=="1" (
        rem echo %copy_speed_check%
        set /a "time_copy=folder_size/copy_speed_check"
        echo Приблизительное время копирования составит: !time_copy! c
        set /p choicee="Продолжить? (y/n) "
        if "%choicee%" equ "n" (
            exit /b
        ) 
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
        mkdir "%flash_drive_path%\Backup_!year!-!month!-!day!_!hour!-!minute!"
       
        REM Проверка успешного создания папки
        if not exist "%flash_drive_path%\Backup_!year!-!month!-!day!_!hour!-!minute!" (
            echo Не удалось создать папку для резервного копирования.
            goto input_path
        )
        
        for /f "tokens=2 delims== " %%a in ('wmic path Win32_PerfFormattedData_PerfOS_System get SystemUpTime /value ^| find "SystemUpTime"') do set "start_time=%%a"

        xcopy "%source_folder%" "%flash_drive_path%\Backup_!year!-!month!-!day!_!hour!-!minute!\" /E /C /H          
        
        for /f "tokens=2 delims== " %%a in ('wmic path Win32_PerfFormattedData_PerfOS_System get SystemUpTime /value ^| find "SystemUpTime"') do set "end_time=%%a"                                                                                    
              
        rem Вычисляем разницу во времени (в секундах)
        set "time_diff=Unknown"
        set /a "start_time_int=start_time"
        set /a "end_time_int=end_time"
        set /a "time_diff=end_time_int - start_time_int"
        echo.
        rem Выводим результат
        echo Время копирования: !time_diff! с

        rem Расчет скорости копирования в мегабайтах в секунду
        set /a "copy_speed_MBps=folder_size/time_diff"

        echo Скорость копирования: !copy_speed_MBps! б/с

    ) else (
        echo Нет прав на резервное копирование
    ) 
) else (
    echo Недостаточно места на флэш-накопителе или нет прав на резервное копирование
    goto input_path
)
:end
endlocal
exit /b

:run_script2
echo Launching script 2...

rem Установка количества дней, после которых папки считаются устаревшими
set "days_to_keep=10"
    
rem Определяем текущую дату в формате ГГГГММДД
for /f "tokens=1-3 delims=-" %%a in ('echo %date%') do set "current_date=%%a%%b%%c"

rem Определяем дату, которая была days_to_keep дней назад
set /a "days_to_subtract=%days_to_keep%"
set "threshold_date=%current_date%"
set "year=%threshold_date:~6,4%"
set "check=%threshold_date:~3,1%"
if !check! lss 1 (
    set "month=%threshold_date:~4,1%"
) else (
    set "month=%threshold_date:~3,2%"
)
set "check=%threshold_date:~0,1%"
if !check! lss 1 (
    set "day=%threshold_date:~1,1%"
) else (
    set "day=%threshold_date:~0,2%"

)

:subtract_days
if %days_to_subtract% leq 0 goto :done_subtract

set /a "days_to_subtract-=1"
set /a "day=day-1"

if !day! lss 1 (
    set /a "month-=1"
    if !month! lss 1 (
        set /a "year-=1"
        set "month=12"
    )
    set "days_in_month=31"
    if !month! equ 4 set "days_in_month=30"
    if !month! equ 6 set "days_in_month=30"
    if !month! equ 9 set "days_in_month=30"
    if !month! equ 11 set "days_in_month=30"
    if !month! equ 2 (
        set /a "leap=year%%4"
        if !leap! equ 0 set "days_in_month=29"
        if !leap! equ 1 set "days_in_month=28"
    )
    
    set /a "day=days_in_month+day"
)                                       

goto :subtract_days

:done_subtract
if !day! lss 10 set "day=0!day!"
if !month! lss 10 set "month=0!month!"
set "threshold_date=!year!!month!!day!"
rem Удаляем папки, которые старше threshold_date
for /d %%i in ("%flash_drive_path%Backup_*") do (
    set "folder_date=%%~ni"
    set "folder_date=!folder_date:~7,4!!folder_date:~12,2!!folder_date:~15,2!"
    if !folder_date! lss %threshold_date% (
        echo Deleting folder: %%i
        rd /s /q "%%i"
    )
)

endlocal
exit /b
