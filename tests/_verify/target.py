# Small target file for the adversarial-verify test. 3 real bugs, nothing else.
def accumulate(item, acc=[]):        # BUG A (real): mutable default argument
    acc.append(item)
    return acc


def parse(raw):
    try:
        return int(raw)
    except:                          # BUG B (real): bare except swallows everything
        pass


def is_missing(x):
    return x == None                 # BUG C (real): should be `is None`
