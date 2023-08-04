*** Settings ***
Default Tags     OpenDataHub
Resource         ${RESOURCE_PATH}/ODS.robot
Resource         ${RESOURCE_PATH}/Common.robot
Resource         ${RESOURCE_PATH}/Page/ODH/JupyterHub/JupyterHubSpawner.robot
Resource         ${RESOURCE_PATH}/Page/ODH/JupyterHub/JupyterLabLauncher.robot

Library          DebugLibrary

Suite Setup      Begin ODH Web Test
Suite Teardown   End Web Test

*** Test Cases ***
Open ODH Dashboard
  [Documentation]   Logs into the ODH Dashboard and navigate to the notebook spawner UI

  Launch Jupyter From RHODS Dashboard Link
  Login To Jupyterhub  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
  ${authorization_required} =  Is Service Account Authorization Required
  Run Keyword If  ${authorization_required}  Authorize jupyterhub service account
  Wait Until Page Contains  Start a notebook server

Can Spawn Notebook
  [Documentation]   Spawns the user notebook

  # We need to skip this testcase if the user has an existing pod
  Fix Spawner Status
  Capture Page Screenshot

  # Due to an issue with ods-ci checking for downstream versions we need to
  # check the box to "Start server in current tab" to since the automation is skipping the
  # logic that handles the selection for showing JupyterLab in current vs new tab
  # See https://github.com/red-hat-data-services/ods-ci/blob/1.20.0/tests/Resources/Page/ODH/JupyterHub/JupyterHubSpawner.robot#L201
  Click Element  id:checkbox-notebook-browser-tab-preference

  Spawn ODH Notebook With Arguments  image=jupyter-datascience-notebook

Can Launch Python3 Smoke Test Notebook
  [Documentation]   Execute simple commands in the Jupyter notebook to verify basic functionality 

  Add and Run JupyterLab Code Cell in Active Notebook  import os
  Add and Run JupyterLab Code Cell in Active Notebook  print("Hello World!")
  Capture Page Screenshot

  JupyterLab Code Cell Error Output Should Not Be Visible

  Add and Run JupyterLab Code Cell in Active Notebook  !pip freeze
  Wait Until JupyterLab Code Cell Is Not Active
  Capture Page Screenshot

  #Get the text of the last output cell
  ${output} =  Get Text  (//div[contains(@class,"jp-OutputArea-output")])[last()]
  Should Not Match  ${output}  ERROR*
  Stop JupyterLab Notebook Server

# All of the keywords below are workarounds until official support for ODH automation is added to ods-ci
#TODO: Update ods-ci to support ODH builds of dashboard and associated components
*** Keywords ***
Wait for ODH Dashboard to Load
    [Arguments]  ${dashboard_title}="${ODH_DASHBOARD_PROJECT_NAME}"   ${odh_logo_xpath}=//img[@alt="${ODH_DASHBOARD_PROJECT_NAME} Logo"]
    Wait For Condition    return document.title == ${dashboard_title}    timeout=15s
    Wait Until Page Contains Element    xpath:${odh_logo_xpath}    timeout=15s

Begin ODH Web Test
    # This is a duplicate of the Begin Web Test in ods-ci that does not default to hardcoded
    # text/assets from downstream
    [Documentation]  This keyword should be used as a Suite Setup; it will log in to the
    ...              ODH dashboard, checking that the spawner is in a ready state before
    ...              handing control over to the test suites.

    Set Library Search Order  SeleniumLibrary

    Open Browser  ${ODH_DASHBOARD_URL}  browser=${BROWSER.NAME}  options=${BROWSER.OPTIONS}
    Login To RHODS Dashboard  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
    ${authorization_required} =  Is Service Account Authorization Required
    Run Keyword If  ${authorization_required}  Authorize jupyterhub service account
    Wait for RHODS Dashboard to Load

    # Workaround for issues when the dashboard reports "No Components Found" on the initial load
    Wait Until Element Is Not Visible  xpath://h5[.="No Components Found"]   120seconds
    Wait Until Element Is Visible   xpath://div[contains(@class,"pf-c-card") and @data-id="jupyter"]/div[contains(@class,"pf-c-card__footer")]/a   120seconds

    Launch Jupyter From RHODS Dashboard Link
    Login To Jupyterhub  ${TEST_USER.USERNAME}  ${TEST_USER.PASSWORD}  ${TEST_USER.AUTH_TYPE}
    Fix Spawner Status
    Go To  ${ODH_DASHBOARD_URL}

Verify Notebook Name And Image Tag
    [Documentation]    Verifies that expected notebook is spawned and image tag is not latest
    [Arguments]    ${user_data}

    @{notebook_details} =    Split String    ${userdata}[1]    :
    ${notebook_name} =    Strip String    ${notebook_details}[1]
    Spawned Image Check    image=${notebook_name}
    Should Not Be Equal As Strings    ${notebook_details}[2]    latest    strip_spaces=True

Spawn ODH Notebook With Arguments  # robocop: disable
    # Temporary addition of keyword for fix of ci
    # TODO: Remove the keywords once the fix is updated in ods-ci.
    [Documentation]  Selects required settings and spawns a notebook pod. If it fails due to timeout or other issue
    ...              It will try again ${retries} times (Default: 1) after ${retries_delay} delay (Default: 0 seconds).
    ...              Environment variables can be passed in as kwargs by creating a dictionary beforehand
    ...              e.g. &{test-dict}  Create Dictionary  name=robot  password=secret
    ...              ${version} controls if the default or previous version is selected (default | previous)
    [Arguments]  ${retries}=1  ${retries_delay}=0 seconds  ${image}=s2i-generic-data-science-notebook  ${size}=Small
    ...    ${spawner_timeout}=600 seconds  ${gpus}=0  ${refresh}=${False}  ${same_tab}=${True}
    ...    ${username}=${TEST_USER.USERNAME}  ${password}=${TEST_USER.PASSWORD}  ${auth_type}=${TEST_USER.AUTH_TYPE}
    ...    ${version}=default    &{envs}
    ${spawn_fail} =  Set Variable  True
    FOR  ${index}  IN RANGE  0  1+${retries}
        ${spawner_ready} =    Run Keyword And Return Status    Wait Until JupyterHub Spawner Is Ready
        IF  ${spawner_ready}==True
            Select Notebook Image  ${image}  
            Select Container Size  ${size}
            ${gpu_visible} =    Run Keyword And Return Status    Wait Until GPU Dropdown Exists
            IF  ${gpu_visible}==True and ${gpus}>0
                Set Number Of Required GPUs  ${gpus}
            ELSE IF  ${gpu_visible}==False and ${gpus}>0
                IF    ${index} < ${retries}
                    Sleep    30s    reason=Wait for GPU to free up
                    SeleniumLibrary.Reload Page
                    Wait Until JupyterHub Spawner Is Ready
                    CONTINUE
                ELSE
                    Fail  GPUs required but not available
                END
            END
            IF   ${refresh}
                Reload Page
                Capture Page Screenshot    reload.png
                Wait Until JupyterHub Spawner Is Ready
            END
            IF  &{envs}
                Remove All Spawner Environment Variables
                FOR  ${key}  ${value}  IN  &{envs}[envs]
                    Sleep  1
                    Add Spawner Environment Variable  ${key}  ${value}
                END
            END
            Spawn Notebook    ${spawner_timeout}    ${same_tab}
            ${oauth_prompt_visible} =  Is OpenShift OAuth Login Prompt Visible
            IF  ${oauth_prompt_visible}  Click Button  Log in with OpenShift
            Run Keyword And Warn On Failure   Login To Openshift  ${username}  ${password}  ${auth_type}
            ${authorization_required} =  Is Service Account Authorization Required
            IF  ${authorization_required}  Authorize jupyterhub service account
            Wait Until Page Contains Element  xpath://div[@id="jp-top-panel"]  timeout=60s
            Sleep    2s    reason=Wait for a possible popup
            Maybe Close Popup
            Open New Notebook In Jupyterlab Menu
            Spawned Image Check  ${image} 
            ${spawn_fail} =  Has Spawn Failed
            Exit For Loop If  ${spawn_fail} == False
            Reload Page
        ELSE
            Sleep  ${retries_delay}
            Reload Page
        END
    END
    IF  ${spawn_fail} == True
        Fail  msg= Spawner failed loading after ${retries} retries
    END
