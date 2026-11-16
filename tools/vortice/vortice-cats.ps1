# Which listing group and filter facets each Vortice page belongs to (g: the
# ventilation listing's tab - home, duct, ind, hrv, acc - and t: its type
# filter). Shared by vortice-hub.ps1, which builds the listing, and
# vortice-gen.ps1, whose comparison and related blocks stay inside a page's own
# group (the user, 2026-11-16: "why a recuperation device is compared to just
# household ventilations"). Dot-source it: . (Join-Path $PSScriptRoot 'vortice-cats.ps1')

$CAT = @{
  'vortice-me'=@{g='home';t='wall'}; 'vortice-m'=@{g='home';t='wall,window'};         'vortice-mf'=@{g='home';t='wall,ceiling'}
  'vortice-mfo'=@{g='home';t='wall,ceiling'};'vortice-mg'=@{g='home';t='duct'}
  'vortice-qe'=@{g='home';t='wall'};         'vortice-ariett'=@{g='home';t='wall'}
  'vortice-ar-p'=@{g='home';t='window'}
  'vortice-ca-v0'=@{g='duct';t='duct'};      'vortice-ca-md'=@{g='duct';t='duct'}
  'vortice-ca-il'=@{g='duct';t='duct'};      'vortice-lineo'=@{g='duct';t='duct'}
  # LINEO QUIET was missing here, so it carried no category and no type and fell
  # out of every filter -- visible only with nothing ticked. It is the acoustically
  # jacketed LINEO, named "LINEO QUIET duct fan" in vortice-families.json, so it
  # takes the same pair as the LINEO beside it.
  'vortice-lineo-quiet'=@{g='duct';t='duct'}
  # The ranges split out of CA IL, LINEO, LINEO QUIET and VORT HR / HRI take
  # the pair of the page they left; the HR 300 is a wall or floor unit.
  'vortice-ca-rm-es'=@{g='duct';t='duct'};   'vortice-lineo-q'=@{g='duct';t='duct'}
  'vortice-lineo-quiet-es'=@{g='duct';t='duct'}; 'vortice-lineo-t-quiet'=@{g='duct';t='duct'}
  'vortice-lineo-q-t'=@{g='duct';t='duct'}
  'vortice-hr-neti'=@{g='hrv';t='wall'}
  # the HRW units are through-the-wall, decentralised: heat recovery, wall
  'vortice-hrw-all'=@{g='hrv';t='wall'};     'vortice-hrw-mono'=@{g='hrv';t='wall'}
  'vortice-qbk'=@{g='ind';t='centrifugal'};  'vortice-qbk-sal'=@{g='ind';t='centrifugal'}
  'vortice-cms'=@{g='ind';t='centrifugal'};  'vortice-roof'=@{g='ind';t='roof'}
  'vortice-hri'=@{g='hrv';t='ceiling'}
  # 2026-10-01, from the stock list: the rectangular CA IL ranges sit with the
  # other duct fans, the ANGOL K / AXIAL K kitchen-cabinet fans with the
  # residential ones, and the accessories get a category of their own (no
  # type, no airflow - see $air below)
  'vortice-ca-il-rect'=@{g='duct';t='duct'}; 'vortice-k'=@{g='home';t='duct'}
  'vortice-accessories'=@{g='acc';t=''}
}
