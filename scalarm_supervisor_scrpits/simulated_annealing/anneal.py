import scipy.optimize as scopt
import json
import sys
from scalarmapi import Scalarm


def call_scalarm(x):
    print 'schedule_point'
    scalarm.schedule_point(x)
    print 'get_result'
    return scalarm.get_result(x)


def to_csv(data):
    s = str(data[0])
    for l in data[1:]:
        s += ','
        s += str(l)
    return s


if __name__ == "__main__":
    if len(sys.argv) < 2:
        config_file = open('config.json')
    else:
        config_file = open(sys.argv[1])
    config = json.load(config_file)
    config_file.close()
    scalarm = Scalarm(config['user'],
                      config['password'],
                      config['experiment_id'],
                      config["address"],
                      config["parameters_ids"])

    res = scopt.anneal(func=call_scalarm,
                       x0=config['start_point'],
                       full_output=True,
                       schedule=config['schedule'],
                       lower=config['lower_limit'],
                       upper=config['upper_limit'],
                       maxiter=config['maxiter'],
                       dwell=config['dwell'])

    print 'mark_as_complete'
    scalarm.mark_as_complete()
    print 'set_result'
    scalarm.set_result({'result': res[1], 'values': to_csv(res[0])})


