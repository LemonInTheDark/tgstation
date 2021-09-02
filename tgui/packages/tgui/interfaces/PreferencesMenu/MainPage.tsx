import { classes } from "common/react";
import { sendAct, useBackend, useLocalState } from "../../backend";
import { Autofocus, Box, Button, ByondUi, Dropdown, FitText, Flex, Icon, Input, LabeledList, NumberInput, Popper, Stack, TrackOutsideClicks } from "../../components";
import { AssetWithIcon, createSetPreference, PreferencesMenuData, RandomSetting, ServerSpeciesData } from "./data";
import { CharacterPreview } from "./CharacterPreview";
import { RandomizationButton } from "./RandomizationButton";
import { ServerPreferencesFetcher } from "./ServerPreferencesFetcher";
import { Gender, GENDERS } from "./preferences/gender";
import { Component, createRef } from "inferno";
import features from "./preferences/features";
import { FeatureChoicedServerData, FeatureValueInput } from "./preferences/features/base";
import { resolveAsset } from "../../assets";
import { logger } from "../../logging";
import { filterMap, sortBy } from "common/collections";
import { exhaustiveCheck } from "common/exhaustive";

const CLOTHING_CELL_SIZE = 48;
const CLOTHING_SIDEBAR_ROWS = 7;

const CLOTHING_SELECTION_CELL_SIZE = 48;
const CLOTHING_SELECTION_WIDTH = 5.4;
const CLOTHING_SELECTION_MULTIPLIER = 5.2;

// MOTHBLOCKS TODO: Put this in the datum, or perhaps derive it?
// Actually, just put these all in the feature files.
// ACTUALLY actually, just put it in compiled data.
const KEYS_TO_NAMES = {
  backpack: "backpack",
  facial_style_name: "facial hair",
  feature_moth_wings: "moth wings",
  hairstyle_name: "hair style",
  jumpsuit_style: "jumpsuit style",
  socks: "socks",
  undershirt: "undershirt",
  underwear: "underwear",
};

const CharacterControls = (props: {
  handleRotate: () => void,
  handleOpenSpecies: () => void,
  gender: Gender,
  setGender: (gender: Gender) => void,
}) => {
  return (
    <Stack>
      <Stack.Item>
        <Button
          onClick={props.handleRotate}
          fontSize="16px"
          icon="undo"
          tooltip="Rotate"
          tooltipPosition="top"
        />
      </Stack.Item>

      <Stack.Item>
        <Button
          onClick={props.handleOpenSpecies}
          fontSize="16px"
          icon="paw"
          tooltip="Species"
          tooltipPosition="top"
        />
      </Stack.Item>

      <Stack.Item>
        <GenderButton gender={props.gender} handleSetGender={props.setGender} />
      </Stack.Item>
    </Stack>
  );
};

const ChoicedSelection = (props: {
  name: string,
  catalog: FeatureChoicedServerData,
  selected: string,
  onSelect: (value: string) => void,
}) => {
  const { catalog } = props;

  if (!catalog.icons) {
    return (
      <Box color="red">
        Provided catalog had no icons!
      </Box>
    );
  }

  return (
    <Box style={{
      background: "white",
      padding: "5px",
      width: `${CLOTHING_SELECTION_CELL_SIZE * CLOTHING_SELECTION_WIDTH}px`,
      height:
        `${CLOTHING_SELECTION_CELL_SIZE * CLOTHING_SELECTION_MULTIPLIER}px`,
    }}>
      <Stack vertical fill>
        <Stack.Item>
          <Box style={{
            "border-bottom": "1px solid #888",
            "font-size": "14px",
            "text-align": "center",
          }}>Select {props.name}
          </Box>
        </Stack.Item>

        <Stack.Item overflowY="scroll">
          <Autofocus>
            <Flex wrap>
              {Object.entries(catalog.icons).map(([name, image], index) => {
                return (
                  <Flex.Item
                    key={index}
                    basis={`${CLOTHING_SELECTION_CELL_SIZE}px`}
                    style={{
                      padding: "5px",
                    }}
                  >
                    <Button
                      onClick={() => {
                        props.onSelect(name);
                      }}
                      selected={name === props.selected}
                      tooltip={name}
                      tooltipPosition="right"
                      style={{
                        height: `${CLOTHING_SELECTION_CELL_SIZE}px`,
                        width: `${CLOTHING_SELECTION_CELL_SIZE}px`,
                      }}
                    >
                      <Box className={classes(["preferences32x32", image, "centered-image"])} />
                    </Button>
                  </Flex.Item>
                );
              })}
            </Flex>
          </Autofocus>
        </Stack.Item>
      </Stack>
    </Box>
  );
};

const GenderButton = (props: {
  handleSetGender: (gender: Gender) => void,
  gender: Gender,
}, context) => {
  const [genderMenuOpen, setGenderMenuOpen] = useLocalState(context, "genderMenuOpen", false);

  return (
    <Popper options={{
      placement: "right-end",
    }} popperContent={(
      genderMenuOpen
        && (
          <Stack backgroundColor="white" ml={0.5} p={0.3}>
            {[Gender.Male, Gender.Female, Gender.Other].map(gender => {
              return (
                <Stack.Item key={gender}>
                  <Button
                    selected={gender === props.gender}
                    onClick={() => {
                      props.handleSetGender(gender);
                      setGenderMenuOpen(false);
                    }}
                    fontSize="16px"
                    icon={GENDERS[gender].icon}
                    tooltip={GENDERS[gender].text}
                    tooltipPosition="top"
                  />
                </Stack.Item>
              );
            })}
          </Stack>
        )
    )}>
      <Button
        onClick={() => {
          setGenderMenuOpen(!genderMenuOpen);
        }}
        fontSize="16px"
        icon={GENDERS[props.gender].icon}
        tooltip="Gender"
        tooltipPosition="top"
      />
    </Popper>
  );
};

const NameInput = (props: {
  handleUpdateName: (name: string) => void,
  name: string,
}, context) => {
  const [lastNameBeforeEdit, setLastNameBeforeEdit]
    = useLocalState<string | null>(context, "lastNameBeforeEdit", null);
  const editing = lastNameBeforeEdit === props.name;

  const updateName = (e, value) => {
    setLastNameBeforeEdit(null);
    props.handleUpdateName(value);
  };

  return (
    <Button captureKeys={!editing} onClick={() => {
      setLastNameBeforeEdit(props.name);
    }} textAlign="center" width="100%" height="28px">
      <Stack align="center" fill>
        <Stack.Item>
          <Icon style={{
            "color": "rgba(255, 255, 255, 0.5)",
            "font-size": "17px",
          }} name="edit" />
        </Stack.Item>

        <Stack.Item grow position="relative">
          {editing && (
            <Input
              autoSelect
              onEnter={updateName}
              onChange={updateName}
              onEscape={() => {
                setLastNameBeforeEdit(null);
              }}
              value={props.name}
            />
          ) || (
            <FitText maxFontSize={16} maxWidth={130}>
              {props.name}
            </FitText>
          )}

          <Box style={{
            "border-bottom": "2px dotted rgba(255, 255, 255, 0.8)",
            right: "50%",
            transform: "translateX(50%)",
            position: "absolute",
            width: "90%",
            bottom: "-1px",
          }} />
        </Stack.Item>

        <Stack.Item>
          <Button as="span" tooltip="Alternate Names" tooltipPosition="bottom" style={{
            background: "rgba(0, 0, 0, 0.7)",
            position: "absolute",
            right: "2px",
            top: "50%",
            transform: "translateY(-50%)",
            width: "2%",
          }}>
            <Icon name="ellipsis-v" style={{
              "position": "relative",
              "left": "1px",
              "min-width": "0px",
            }} />
          </Button>
        </Stack.Item>
      </Stack>
    </Button>
  );
};

const MainFeature = (props: {
  catalog: FeatureChoicedServerData,
  currentValue: AssetWithIcon,
  isOpen: boolean,
  handleClose: () => void,
  handleOpen: () => void,
  handleSelect: (newClothing: string) => void,
  name: string,
  randomization?: RandomSetting,
  setRandomization: (newSetting: RandomSetting) => void,
}) => {
  const {
    catalog,
    currentValue,
    isOpen,
    handleOpen,
    handleClose,
    handleSelect,
    name,
    randomization,
    setRandomization,
  } = props;

  return (
    <Popper options={{
      placement: "bottom-start",
    }} popperContent={isOpen && (
      <TrackOutsideClicks onOutsideClick={props.handleClose}>
        <ChoicedSelection
          name={name}
          catalog={catalog}
          selected={currentValue.value}
          onSelect={handleSelect}
        />
      </TrackOutsideClicks>
    )}>
      <Button
        onClick={() => {
          if (isOpen) {
            handleClose();
          } else {
            handleOpen();
          }
        }}
        style={{
          height: `${CLOTHING_CELL_SIZE}px`,
          width: `${CLOTHING_CELL_SIZE}px`,
        }}
        position="relative"
        tooltip={currentValue.value}
        tooltipPosition="right"
      >
        <Box
          className={classes([
            "preferences32x32",
            currentValue.icon,
            "centered-image",
          ])}
          style={{
            transform: randomization
              ? "translateX(-70%) translateY(-70%) scale(1.1)"
              : "translateX(-50%) translateY(-50%) scale(1.3)",
          }}
        />

        {(randomization && <RandomizationButton
          dropdownProps={{
            dropdownStyle: {
              bottom: 0,
              position: "absolute",
              right: "1px",
            },

            onOpen: (event) => {
              // We're a button inside a button.
              // Did you know that's against the W3C standard? :)
              event.cancelBubble = true;
              event.stopPropagation();
            },
          }}
          value={randomization}
          setValue={setRandomization}
        />)}
      </Button>
    </Popper>
  );
};

const createSetRandomization = (
  act: typeof sendAct,
  preference: string,
) => (newSetting: RandomSetting) => {
  act("set_random_preference", {
    preference,
    value: newSetting,
  });
};

const sortPreferences = sortBy<[string, unknown]>(
  ([featureId, _]) => {
    const feature = features[featureId];
    return feature?.name;
  });

const PreferenceList = (props: {
  act: typeof sendAct,
  preferences: Record<string, unknown>,
  randomizations: Record<string, RandomSetting>,
}) => {
  return (
    <Stack.Item basis="50%" grow style={{
      background: "rgba(0, 0, 0, 0.5)",
      padding: "4px",
    }}>
      <LabeledList>
        {
          sortPreferences(Object.entries(props.preferences))
            .map(([featureId, value]) => {
              const feature = features[featureId];
              const randomSetting = props.randomizations[featureId];

              if (feature === undefined) {
                return (
                  <Stack.Item key={featureId}>
                    <b>Feature {featureId} is not recognized.</b>
                  </Stack.Item>
                );
              }

              return (
                <LabeledList.Item
                  key={featureId}
                  label={feature.name}
                  verticalAlign="middle"
                >
                  <Stack fill>
                    {randomSetting && (
                      <Stack.Item>
                        <RandomizationButton
                          setValue={createSetRandomization(
                            props.act,
                            featureId,
                          )}
                          value={randomSetting}
                        />
                      </Stack.Item>
                    )}

                    <Stack.Item grow>
                      <FeatureValueInput
                        act={props.act}
                        feature={feature}
                        featureId={featureId}
                        value={value}
                      />
                    </Stack.Item>
                  </Stack>
                </LabeledList.Item>
              );
            })
        }
      </LabeledList>
    </Stack.Item>
  );
};

export const MainPage = (props: {
  openSpecies: () => void,
}, context) => {
  const { act, data } = useBackend<PreferencesMenuData>(context);
  const [currentClothingMenu, setCurrentClothingMenu]
    = useLocalState<string | null>(context, "currentClothingMenu", null);

  return (
    <ServerPreferencesFetcher render={(serverData) => {
      const currentSpeciesData = serverData && serverData.species[
        data
          .character_preferences
          .misc
          .species
      ];

      const contextualPreferences = Object.fromEntries(
        Object.entries(
          data.character_preferences.secondary_features
        ).filter(([feature]) => {
          if (!currentSpeciesData) {
            return false;
          }

          return currentSpeciesData.enabled_features
            .indexOf(feature) !== -1;
        })
      );

      const mainFeatures = [
        ...Object.entries(data.character_preferences.clothing),
        ...Object.entries(data.character_preferences.features)
          .filter(([featureName]) => {
            if (!currentSpeciesData) {
              return false;
            }

            // MOTHBLOCKS TODO: This is stupid, let's figure it out
            return currentSpeciesData.enabled_features
              .indexOf(featureName) !== -1
                || currentSpeciesData.enabled_features
                  .indexOf(featureName.split("feature_")[1]) !== -1;
          }),
      ];

      const randomBodyEnabled
        = data.character_preferences.non_contextual.random_body;

      const getRandomization = (
        preferences: Record<string, unknown>
      ): Record<string, RandomSetting> => {
        if (!serverData) {
          return {};
        }

        return Object.fromEntries(filterMap(
          Object.keys(preferences), preferenceKey => {
            if (serverData.random.randomizable.indexOf(preferenceKey) === -1) {
              return undefined;
            }

            if (randomBodyEnabled === RandomSetting.Disabled) {
              return undefined;
            }

            return [
              preferenceKey,
              data.character_preferences.randomization[preferenceKey]
                || RandomSetting.Disabled,
            ];
          }));
      };

      const randomizationOfMainFeatures
        = getRandomization(Object.fromEntries(mainFeatures));

      const nonContextualPreferences
        = {
          ...data.character_preferences.non_contextual,
        };

      if (randomBodyEnabled !== RandomSetting.Disabled) {
        nonContextualPreferences["random_species"]
          = data.character_preferences.randomization["species"];
      }

      return (
        <Stack height={`${CLOTHING_SIDEBAR_ROWS * CLOTHING_CELL_SIZE}px`}>
          <Stack.Item fill>
            <Stack vertical fill>
              <Stack.Item>
                <CharacterControls
                  gender={data.character_preferences.misc.gender}
                  handleOpenSpecies={props.openSpecies}
                  handleRotate={() => {
                    act("rotate");
                  }}
                  setGender={createSetPreference(act, "gender")}
                />
              </Stack.Item>

              <Stack.Item grow>
                <CharacterPreview
                  height="100%"
                  id={data.character_preview_view} />
              </Stack.Item>

              <Stack.Item position="relative">
                <NameInput
                  name={
                    data.character_preferences.names[data.name_to_use].value
                  }
                  handleUpdateName={
                    createSetPreference(act, data.name_to_use)
                  }
                />
              </Stack.Item>

            </Stack>
          </Stack.Item>

          <Stack.Item
            fill
            width={`${(CLOTHING_CELL_SIZE * 2) + 15}px`}
          >
            <Stack height="100%" vertical wrap>
              {mainFeatures
                .map(([clothingKey, clothing]) => {
                  const catalog = (
                    serverData
                        && serverData[clothingKey] as FeatureChoicedServerData
                  );

                  return catalog && (
                    <Stack.Item key={clothingKey} mt={0.5} px={0.5}>
                      <MainFeature
                        catalog={catalog}
                        currentValue={clothing}
                        isOpen={
                          currentClothingMenu === clothingKey
                        }
                        handleClose={() => {
                          setCurrentClothingMenu(null);
                        }}
                        handleOpen={() => {
                          setCurrentClothingMenu(clothingKey);
                        }}
                        handleSelect={createSetPreference(act, clothingKey)}
                        name={KEYS_TO_NAMES[clothingKey]
                          || `NO NAME FOR ${clothingKey}`}
                        randomization={randomizationOfMainFeatures[clothingKey]}
                        setRandomization={createSetRandomization(
                          act,
                          clothingKey,
                        )}
                      />
                    </Stack.Item>
                  );
                })}
            </Stack>
          </Stack.Item>

          <Stack.Item grow basis={0}>
            <Stack vertical fill>
              <PreferenceList
                act={act}
                randomizations={getRandomization(contextualPreferences)}
                preferences={contextualPreferences}
              />

              <PreferenceList
                act={act}
                randomizations={getRandomization(nonContextualPreferences)}
                preferences={nonContextualPreferences}
              />
            </Stack>
          </Stack.Item>
        </Stack>
      );
    }} />
  );
};
