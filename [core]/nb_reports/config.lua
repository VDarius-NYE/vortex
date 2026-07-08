Config = Config or {}

Config.PlayerOpenKey = 'F3'
Config.AdminPanelKey = 'F1'

-- Melyik nb_group szinttől érhető el az admin report panel
Config.AdminPermission = 'support'

Config.Categories = {
    { key = 'player_report', label = 'Játékos Report' },
    { key = 'bug_report',    label = 'Bug Report' },
    { key = 'question',      label = 'Kérdés' },
}
