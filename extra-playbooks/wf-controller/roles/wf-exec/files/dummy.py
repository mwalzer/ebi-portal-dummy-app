import sys 
import time 
import argparse
import bioblend
import requests
import os
from bioblend import galaxy
import zipfile
import boto3
import uuid

VERSION = "0.1"


def check_galaxy(url):
    request = requests.get(url)
    if request.status_code == 200:
        return 1
    else:
        return None


def reading(wf):
    with open(wf, 'r') as f:
        s = f.read()
        null = ""
        return eval(s)


def __main__():
    #parser = argparse.ArgumentParser(version=VERSION)
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--ip', dest="ip", required=True, help="The galaxy servers ip")  # galaxy server IP, e.g. IP 193.62.52.136
    parser.add_argument('-r', '--retry', dest="max", help="max number of retries to connect to galaxy server", default=100)
    parser.add_argument('-w', '--wait', dest="sleep", help="seconds to wait between retries to connect to galaxy server", default=100)
    parser.add_argument('-f', '--workflow', dest="workflow", required=True, help="full path to workflow")
    options = parser.parse_args()
    if len(sys.argv) <= 1:
        parser.print_help()
        sys.exit(1)


    galaxy_url = "http://{ip}:30700".format(ip=options.ip)
    c = 0
    while c < options.max and not check_galaxy(galaxy_url):
        time.sleep(options.sleep)

    if c >= options.max:
        print("Exceeded max. waiting period ({w} sec) for galaxy server. Exiting!".format(w=str(max * sleep)))
        sys.exit(1)

    #This is the default set in galaxy bootstrapping process (see galaxy dockerfile/galaxy_rc.yml in helm chart)
    gig = galaxy.GalaxyInstance(url="http://{ip}:30700".format(ip=options.ip), key='64fe1e39cb2a322272b9cc58091a835b')
    adminkey = gig.users.get_user_apikey(gig.users.get_users()[0]['id'])
    gi = galaxy.GalaxyInstance(url="http://{ip}:30700".format(ip=options.ip), key=adminkey)

    #gi.workflows.get_workflows()
    wf = options.workflow
    fi = reading(wf)
    wfi = gi.workflows.import_workflow_dict(fi)
    #gi.workflows.get_workflows()
    #wfi['id']  # will need that id

    #gi.libraries.get_libraries()
    nl = gi.libraries.create_library("fileinfi_in", description=None, synopsis=None)
    #nl['id']  # will need that id
    inputs = ["https://s3.embassy.ebi.ac.uk/misc/CPTAC_CompRef_00_iTRAQ_07_2Feb12_Cougar_11-10-09.mzML",
              "https://s3.embassy.ebi.ac.uk/misc/CPTAC_CompRef_00_iTRAQ_08_2Feb12_Cougar_11-10-11.mzML",
              "https://s3.embassy.ebi.ac.uk/misc/CPTAC_CompRef_00_iTRAQ_09_2Feb12_Cougar_11-10-09.mzML"]
    r = []
    for furl in inputs:
        r.append(gi.libraries.upload_file_from_url(nl['id'], furl, folder_id=None, file_type='auto', dbkey='?'))


    hi = gi.histories.create_history(name=None)
    #hi['id']  # will need that id

    rh = []
    for li in r:
        rh.append(gi.histories.upload_dataset_from_library(hi['id'], li[0]['id']))


    foo = gi.histories.create_dataset_collection(hi['id'], {'collection_type': 'list', 'name': 'mcl',
                                    'element_identifiers': [{'id': e['id'], 'name': e['name']} for e in rh]})
    #foo['id']  # will need that id
    datamap = dict()
    datamap[0] = {'src': 'hdca', 'id': foo['id']}  # HistoryDatasetCollectionAssociation from foo

    op = gi.workflows.run_workflow(wfi['id'], datamap, history_name='New output history')

    while gi.histories.show_history(op['history'])['state_details']['queued'] > 0:
        time.sleep(options.sleep)

    rfiles = []
    result = gi.histories.show_dataset_collection(op['history_id'], op['outputs'][0])
    for res in result['elements']:
        rfiles.append(gi.histories.show_dataset(op['history_id'], res['id'])['file_name'])

    # with gzip.open('results.txt.gz', 'wb') as f_out:
    #     for rf in rfiles:
    #         with open(rf, 'rb') as f_in:
    #             shutil.copyfileobj(f_in, f_out)

    with zipfile.ZipFile('results.zip', 'w') as f_out:
        for rf in rfiles:
            f_out.write(rf)


    session = boto3.session.Session()
    s3_client = session.client(
        service_name='s3',
        aws_access_key_id = os.environ["SECRET_USERNAME"],
        aws_secret_access_key = os.environ["SECRET_PASSWORD"],
        endpoint_url='https://s3.embassy.ebi.ac.uk',
    )

    # response = s3_client.list_buckets()
    # buckets = [bucket['Name'] for bucket in response['Buckets']]
    # print("Bucket List: %s" % buckets)
    rname = '.'.join([str(uuid.uuid4()), "zip"])
    put_url = s3_client.generate_presigned_url(
        ClientMethod='put_object',
        Params={
            'Bucket': os.environ["SECRET_BUCKET"],
            'Key': rname
        }
    )

    #python put
    with open('results.zip', 'rb') as data:
        requests.put(put_url, data=data)

    report_url = s3_client.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': os.environ["SECRET_BUCKET"],
            'Key': rname
        }
    )
    return report_url


if __name__ == '__main__':
    __main__()
