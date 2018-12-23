import time

import gym
from garage.core.serializable import Serializable


class DelayedEnv(gym.Wrapper, Serializable):
    def __init__(self, env, delay=0.01):
        Serializable.quick_init(self, locals())
        gym.Wrapper.__init__(self, env)

        self._delay = delay

    def step(self, action):
        time.sleep(self._delay)
        return self.step(action)
