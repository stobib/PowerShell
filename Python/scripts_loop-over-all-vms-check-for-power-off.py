#!/usr/bin/env python3
#
# cpaggen - May 16 2015 - Proof of Concept (little to no error checks)
#  - rudimentary args parser
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import atexit
import sys

import argparse
import atexit
import getpass
import ssl
import re

import requests

from pprint import pprint

vm_name = {
  'whitelist_global': ( '^[Ww][i1][n069]', ),
  'blacklist_global': ( 'hr-fin-server', '^v', 'NexposeNA', '^appsen', '^com', '^cvln', '^d42', 'ntz', 'kms', 'spool', 'dd1', 'nethealth', 'phealth', 'rapid7', 'tanium', '^dom', '^dc', 'template', '-dev', 'gold', '-gld', 'b-2[45][506]', 'standroot', 'dev42', 'my00x', 'prowks' ),
}

# Disable Self-signed SSL cert warnings/errors:
requests.packages.urllib3.disable_warnings()
ssl._create_default_https_context = ssl._create_unverified_context
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

def _create_char_spinner():
    """Creates a generator yielding a char based spinner.
    """
    while True:
        for c in '|/-\\':
            yield c

_spinner = _create_char_spinner()

def spinner(label=''):
    """Prints label with a spinner.

    When called repeatedly from inside a loop this prints
    a one line CLI spinner.
    """
    sys.stdout.write("\r\t%s %s" % (label, next(_spinner)))
    sys.stdout.flush()

def answer_vm_question(virtual_machine):
    print("\n")
    choices = virtual_machine.runtime.question.choice.choiceInfo
    default_option = None
    if virtual_machine.runtime.question.choice.defaultIndex is not None:
        ii = virtual_machine.runtime.question.choice.defaultIndex
        default_option = choices[ii]
    choice = None
    while choice not in [o.key for o in choices]:
        print("VM power on is paused by this question:\n\n")
        print("\n".join(textwrap.wrap(
            virtual_machine.runtime.question.text, 60)))
        for option in choices:
            print("\t %s: %s " % (option.key, option.label) )
        if default_option is not None:
            print("default (%s): %s\n" % (default_option.label,
                                          default_option.key) )
        choice = raw_input("\nchoice number: ").strip()
        print("...")
    return choice

def GetVMs(content):
#    print("Getting all VMs ...")
    vm_view = content.viewManager.CreateContainerView(content.rootFolder,
                                                      [vim.VirtualMachine],
                                                      True)
    obj = [vm for vm in vm_view.view]
    vm_view.Destroy()
    return obj

def PrintVmInfo(si, vm, verbose=0, poweron=0, confirm=0):
    vmPowerState = vm.runtime.powerState
    if vm.runtime.powerState == "poweredOn":
      # Normally do nothing for a powered-on host, print status if verbose
      if verbose > 0:
        print("VM: %s [power: %s]" % (vm.name, vm.runtime.powerState) )
    else:
      print("VM: %s [power: %s]" % (vm.name, vm.runtime.powerState) )
      if poweron > 0 and confirm > 0:
        print("\tNOTE: Need to send powerOn command for host, not yet available")

        # now we get to work... calling the vSphere API generates a task...
        task = vm.PowerOn()

        # We track the question ID & answer so we don't end up answering the same
        # questions repeatedly.
        answers = {}
        while task.info.state not in [vim.TaskInfo.State.success,
                                      vim.TaskInfo.State.error]:

            # we'll check for a question, if we find one, handle it,
            # Note: question is an optional attribute and this is how pyVmomi
            # handles optional attributes. They are marked as None.
            if vm.runtime.question is not None:
                question_id = vm.runtime.question.id
                if question_id not in answers.keys():
                    answers[question_id] = answer_vm_question(vm)
                    vm.AnswerVM(question_id, answers[question_id])

            # create a spinning cursor so people don't kill the script...
            spinner(task.info.state)
            print("")

        if task.info.state == vim.TaskInfo.State.error:
            # some vSphere errors only come with their class and no other message
            print("error type: %s" % task.info.error.__class__.__name__)
            print("found cause: %s" % task.info.error.faultCause)
            for fault_msg in task.info.error.faultMessage:
                print(fault_msg.key)
                print(fault_msg.message)
            # A failure could indicate a larger problem, might need to consider exiting script itself
            #sys.exit(-1)

      else:
        print("\tWARNING: Skipping powerOn command, need both command and confirmation: [do powerOn: %s] [confirm: %s]" % (poweron, confirm) )

def GetArgs():
    global vm_name
    """
    Supports the command-line arguments listed below.
    """
    parser = argparse.ArgumentParser(
        description='Process args for retrieving all the Virtual Machines')
    parser.add_argument('-s', '--host', required=True, action='store',
                        help='Remote host to connect to')
    parser.add_argument('-o', '--port', type=int, default=443, action='store',
                        help='Port to connect on')
    parser.add_argument('-u', '--user', required=True, action='store',
                        help='User name to use when connecting to host')
    parser.add_argument('-p', '--password', required=False, action='store',
                        help='Password to use when connecting to host')
    parser.add_argument('-w', '--whitelist', required=False, action='append',
                        help='Whitelist pattern of hosts to act on, overrides default whitelist: [%s]' % ", ".join(vm_name['whitelist_global']) )
    parser.add_argument('-b', '--blacklist', required=False, action='append',
                        help='Blacklist pattern of hosts to act skip, adds to default blacklist: [%s]' % ", ".join(vm_name['blacklist_global']) )
    parser.add_argument('-v', '--verbose', required=False, action='count', default=0,
                        help='Increase verbose debug level' )
    parser.add_argument('-P', '--Power', required=False, action='store_const', default=0, const=1,
                        help='Power On hosts that are found to be off, otherwise only print status info' )
    parser.add_argument('-y', '--yes', required=False, action='store_const', default=0, const=1,
                        help='"Yes" Flag to allow taking action, otherwise only print what is found and needed' )
    args = parser.parse_args()
    if args.password is None:
       args.password = getpass.getpass(prompt='Enter password for host %s and '
                                         'user %s: ' % (args.host,args.user))
    if args.whitelist is None:
      args.whitelist = ()
    if args.blacklist is None:
      args.blacklist = ()
    return args

def main():
    global content, hosts, hostPgDict
#    host, user, password = GetArgs()

    args = GetArgs()

    blacklist = '|'.join( vm_name['blacklist_global'] + args.blacklist )
    patterns = {
        'blacklist': re.compile( blacklist ),
    }
    if len(args.whitelist) > 0:
        whitelist = '|'.join( args.whitelist )
        if args.verbose >= 2: print("Using whitelist override from command-line: %s" % whitelist)
        patterns['whitelist'] = re.compile( whitelist )
    elif len( vm_name['whitelist_global'] ) > 0:
        whitelist = '|'.join( vm_name['whitelist_global'] )
        if args.verbose >= 2: print("Using pre-defined global whitelist: %s" % whitelist )
        patterns['whitelist'] = re.compile( whitelist )
    else:
        if args.verbose >= 1: print("No whitelist, all VMs not blacklisted will be considered valid!")
        patterns['whitelist'] = None

    serviceInstance = SmartConnect(host=args.host,
                                   user=args.user,
                                   pwd=args.password,
                                   port=args.port)
    atexit.register(Disconnect, serviceInstance)
    content = serviceInstance.RetrieveContent()

    vms = GetVMs(content)
    for vm in sorted(vms, key = lambda i: i.name):
        if patterns['blacklist'] is not None:
            if (patterns['blacklist'].search( vm.name )):
                if args.verbose>=2: print("Skipping blacklisted host: %s" % vm.name)
                continue
        if patterns['whitelist'] is not None:
            if (patterns['whitelist'].search( vm.name )):
                if args.verbose>=3: print("Including host...")
            else:
                if args.verbose>=2: print("Skipping host not included by a whitelist [%s] item: %s" % (patterns['whitelist'], vm.name) )
                continue
        PrintVmInfo(serviceInstance, vm, args.verbose, args.Power, args.yes)
#        print("VM: %s" % vm.name)

# Main section
if __name__ == "__main__":
    sys.exit(main())
