import { CheckboxInput, FeatureToggle } from '../base';

export const directional_opacity_pref: FeatureToggle = {
  name: 'Enable directional opacity',
  category: 'GAMEPLAY',
  description: 'Enables/disables partial darkness for things like airlocks/shutters. Marked performance improvement',
  component: CheckboxInput,
};
