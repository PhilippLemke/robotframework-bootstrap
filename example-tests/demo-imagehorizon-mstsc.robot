*** Settings ***
Documentation       Image ImageHorizonLibrary Demo

Library             ImageHorizonLibrary    reference_folder=${CURDIR}${/}images    confidence=0.99
Library             Process


*** Variables ***
${Path}        C:${/}Windows${/}System32${/}mstsc.exe


*** Test Cases ***
Demo RDP Tool
    Launch Application    "${Path}"  
    ${location}=    Wait For    mstsc_icon   timeout=20
    Sleep    1
    ${location}=    Wait For    computer    timeout=2
    ImageHorizonLibrary.Click To The Right Of    ${location}    80
    Type    Click with offset of 80
    ${location}=    Wait For    mstsc_icon_mini   timeout=2
    ImageHorizonLibrary.Click To The Right Of    ${location}    355
