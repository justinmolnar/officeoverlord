return {
    { -- Sprint 1
        sprintName = "Project Kickoff",
        workItems = {
            { id = 's1_item1', name = 'Setup Dev Environment', workload = 40, reward = 600 },
            { id = 's1_item2', name = 'Basic UI Scaffolding', workload = 120, reward = 900 },
            { 
                id = 's1_boss', name = 'Deploy "Hello World"', workload = 280, reward = 1800,
                modifier = { 
                    type = 'disable_top_row', 
                    description = "Management is observing. Top row of desks is disabled for this item.",
                    listeners = {
                        onApply = {
                            {
                                phase = 'BaseApplication',
                                priority = 50,
                                callback = function(self, gameState)
                                    gameState.temporaryEffectFlags.isTopRowDisabled = true
                                end
                            }
                        }
                    }
                }
            },
        }
    },
    { -- Sprint 2
        sprintName = "First Feature Spike",
        workItems = {
            { id = 's2_item1', name = 'User Story #A-51', workload = 480, reward = 1200 },
            { 
                id = 's2_item2', name = 'Integrate New Library', workload = 700, reward = 1600,
                modifier = { 
                    type = 'disable_remote_workers', 
                    description = "Mandatory in-office day! Remote employees are unavailable for this item.",
                    listeners = {
                        onApply = {
                            {
                                phase = 'BaseApplication',
                                priority = 50,
                                callback = function(self, gameState)
                                    gameState.temporaryEffectFlags.isRemoteWorkDisabled = true
                                end
                            }
                        }
                    }
                }
            },
            { id = 's2_boss', name = 'Feature Demo', workload = 1100, reward = 3000 },
        }
    },
    { -- Sprint 3
        sprintName = "Q2 Crunch",
        workItems = {
            { id = 's3_item1', name = 'Bug Bash', workload = 1400, reward = 2000 },
            { id = 's3_item2', name = 'Performance Tuning', workload = 1900, reward = 2800 },
            { 
                id = 's3_boss', name = 'Critical Security Patch', workload = 2500, reward = 4500,
                modifier = { 
                    type = 'disable_shop', 
                    description = "A spending freeze is in effect. The Shop is disabled for this item.",
                    listeners = {
                        onApply = {
                            {
                                phase = 'BaseApplication',
                                priority = 50,
                                callback = function(self, gameState)
                                    gameState.temporaryEffectFlags.isShopDisabled = true
                                end
                            }
                        }
                    }
                }
            },
        }
    },
    { -- Sprint 4
        sprintName = "Scaling Up",
        workItems = {
            { id = 's4_item1', name = 'Database Migration', workload = 3000, reward = 3500 },
            { id = 's4_item2', name = 'Refactor Legacy Code', workload = 4000, reward = 4500,
              modifier = { 
                  type = 'disable_remote_workers', 
                  description = "This complex task requires everyone on-site. Remote staff unavailable.",
                  listeners = {
                      onApply = {
                          {
                              phase = 'BaseApplication',
                              priority = 50,
                              callback = function(self, gameState)
                                  gameState.temporaryEffectFlags.isRemoteWorkDisabled = true
                              end
                          }
                      }
                  }
              }
            },
            { id = 's4_boss', name = 'Launch Ad Campaign', workload = 5500, reward = 7000 },
        }
    },
    { -- Sprint 5
        sprintName = "Mid-Project Review",
        workItems = {
            { id = 's5_item1', name = 'Tech Debt Repayment', workload = 6500, reward = 5000 },
            { id = 's5_item2', name = 'A/B Testing Framework', workload = 8000, reward = 6000 },
            { id = 's5_boss', name = 'Investor Presentation', workload = 10000, reward = 10000,
              modifier = { 
                  type = 'disable_top_row', 
                  description = "Investors are touring the main floor. Top row desks are unavailable.",
                  listeners = {
                      onApply = {
                          {
                              phase = 'BaseApplication',
                              priority = 50,
                              callback = function(self, gameState)
                                  gameState.temporaryEffectFlags.isTopRowDisabled = true
                              end
                          }
                      }
                  }
              }
            },
        }
    },
    { -- Sprint 6
        sprintName = "The Final Stretch",
        workItems = {
            { id = 's6_item1', name = 'Final UI Polish', workload = 12000, reward = 7500 },
            { id = 's6_item2', name = 'Server Stress Test', workload = 15000, reward = 9000 },
            { id = 's6_boss', name = 'Code Freeze & Merge', workload = 20000, reward = 15000 },
        }
    },
    { -- Sprint 7
        sprintName = "Launch Week",
        workItems = {
            { id = 's7_item1', name = 'Deploy to Production', workload = 25000, reward = 12000 },
            { id = 's7_item2', name = 'Monitor Initial Traffic', workload = 32000, reward = 15000 },
            { id = 's7_boss', name = 'Emergency Hotfix', workload = 40000, reward = 25000,
              modifier = { 
                  type = 'disable_shop', 
                  description = "All hands on deck! The shop is closed until this is resolved.",
                  listeners = {
                      onApply = {
                          {
                              phase = 'BaseApplication',
                              priority = 50,
                              callback = function(self, gameState)
                                  gameState.temporaryEffectFlags.isShopDisabled = true
                              end
                          }
                      }
                  }
              }
            },
        }
    },
    { -- Sprint 8
        sprintName = "Post-Launch Support",
        workItems = {
            { id = 's8_item1', name = 'Analyze Feedback', workload = 50000, reward = 20000 },
            { id = 's8_item2', name = 'Plan V2.0', workload = 65000, reward = 30000 },
            { id = 's8_boss', name = 'Acquisition Offer', workload = 100000, reward = 100000 },
        }
    },
}