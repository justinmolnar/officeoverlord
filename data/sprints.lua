-- data/sprints.lua
-- Sprint definitions with work items but without hardcoded modifiers

local sprints = {
    {
        sprintName = "Onboarding Sprint",
        workItems = {
            { id = "onboarding_1", name = "Employee Handbook", workload = 100, reward = 200 },
            { id = "onboarding_2", name = "Setup Workstations", workload = 150, reward = 300 },
            { id = "onboarding_boss", name = "First Day Jitters", workload = 300, reward = 500 }
        }
    },
    {
        sprintName = "Foundation Building",
        workItems = {
            { id = "foundation_1", name = "Process Documentation", workload = 200, reward = 400 },
            { id = "foundation_2", name = "Team Communication", workload = 300, reward = 450 },
            { id = "foundation_boss", name = "Quarterly Review", workload = 600, reward = 700 }
        }
    },
    {
        sprintName = "Scaling Operations",
        workItems = {
            { id = "scaling_1", name = "Workflow Optimization", workload = 400, reward = 500 },
            { id = "scaling_2", name = "Quality Assurance", workload = 600, reward = 600 },
            { id = "scaling_boss", name = "Client Presentation", workload = 1200, reward = 900 }
        }
    },
    {
        sprintName = "Market Expansion",
        workItems = {
            { id = "expansion_1", name = "Market Research", workload = 800, reward = 650 },
            { id = "expansion_2", name = "Product Development", workload = 1200, reward = 750 },
            { id = "expansion_boss", name = "Launch Campaign", workload = 2400, reward = 1200 }
        }
    },
    {
        sprintName = "Innovation Phase",
        workItems = {
            { id = "innovation_1", name = "R&D Initiative", workload = 1600, reward = 800 },
            { id = "innovation_2", name = "Prototype Testing", workload = 2400, reward = 900 },
            { id = "innovation_boss", name = "Patent Filing", workload = 3200, reward = 1500 }
        }
    },
    {
        sprintName = "Global Reach",
        workItems = {
            { id = "global_1", name = "International Compliance", workload = 2100, reward = 1000 },
            { id = "global_2", name = "Localization Project", workload = 3200, reward = 1100 },
            { id = "global_boss", name = "World Domination", workload = 6300, reward = 2000 }
        }
    },
    {
        sprintName = "Digital Transformation",
        workItems = {
            { id = "digital_1", name = "Legacy System Migration", workload = 4200, reward = 1200 },
            { id = "digital_2", name = "AI Integration", workload = 6300, reward = 1300 },
            { id = "digital_boss", name = "Singularity Protocol", workload = 12600, reward = 2500 }
        }
    },
    {
        sprintName = "Final Convergence",
        workItems = {
            { id = "final_1", name = "Ultimate Optimization", workload = 8300, reward = 1500 },
            { id = "final_2", name = "Perfect Efficiency", workload = 12600, reward = 1600 },
            { id = "final_boss", name = "Corporate Transcendence", workload = 25000, reward = 3000 }
        }
    }
}

return sprints