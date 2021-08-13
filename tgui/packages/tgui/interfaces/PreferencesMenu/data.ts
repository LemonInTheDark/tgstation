import { BooleanLike } from "common/react";
import { sendAct } from "../../backend";
import { Gender } from "./preferences/gender";

export type CharacterProfile = {
  name: string;
};

export type AssetWithIcon = {
  icon: string;
  value: string;
};

export enum Food {
  Alcohol = "ALCOHOL",
  Breakfast = "BREAKFAST",
  Cloth = "CLOTH",
  Dairy = "DAIRY",
  Fried = "FRIED",
  Fruit = "FRUIT",
  Grain = "GRAIN",
  Gross = "GROSS",
  Junkfood = "JUNKFOOD",
  Meat = "MEAT",
  Pineapple = "PINEAPPLE",
  Raw = "RAW",
  Sugar = "SUGAR",
  Toxic = "TOXIC",
  Vegetables = "VEGETABLES",
}

export enum JobPriority {
  Low = 1,
  Medium = 2,
  High = 3,
}

export type Name = {
  explanation: string;
  value: string;
};

export type ServerSpeciesData = {
  name: string;

  use_skintones: BooleanLike;
  sexes: BooleanLike;

  features: string[];

  liked_food: Food[];
  disliked_food: Food[];
  toxic_food: Food[];
};

export const createSetPreference = (
  act: typeof sendAct,
  preference: string
) => (value: string) => {
  act("set_preference", {
    preference,
    value,
  });
};

export enum Window {
  Character = 0,
  Game = 1,
}

export type PreferencesMenuData = {
  character_preview_view: string;
  character_profiles: (CharacterProfile | null)[];

  character_preferences: {
    clothing: Record<string, AssetWithIcon>;
    features: Record<string, AssetWithIcon>;
    game_preferences: Record<string, unknown>;
    non_contextual: Record<string, unknown>;
    secondary_features: Record<string, unknown>;

    names: Record<string, Name>;

    misc: {
      gender: Gender;
      species: string;
    };
  };

  job_preferences: Record<string, JobPriority>;

  generated_preference_values?: Record<string, Record<string, string>>;
  keybindings: Record<string, string[]>;
  overflow_role: string;
  selected_antags: string[];
  selected_quirks: string[];
  species: Record<string, ServerSpeciesData>;

  active_name: string;
  name_to_use: string;

  window: Window;
};
