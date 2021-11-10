package main

import (
	"encoding/json"
	"io/ioutil"
	"fmt"
	"os"
	"log"
	"strings"
)

type State struct {
	ID string `json:"ID"`
	ID_GREP string `json:"ID_GREP"`
	STATE string `json:"STATE"`
}

var state_file State
var STATE_JSON string
var DRIVER_PATH string

func read_json(file string) State {
	jsonFile, err := os.Open(file)
	if err != nil {
		fmt.Println(err)
	}
        byteValue, _ := ioutil.ReadAll(jsonFile)
	defer jsonFile.Close()
	var state State
        json.Unmarshal(byteValue, &state)
	return state
}

func write_json(contents State) {
	jsonString, _ := json.Marshal(contents)
	os.WriteFile(
		STATE_JSON, 
		jsonString, 
		os.ModePerm,
	)
}

func update_id(grep string, fallback_id string) string {
	files, err := ioutil.ReadDir(DRIVER_PATH)
	if err != nil {
		log.Fatal(err)
	}
	var device_id string
	for _, f := range files {
		if strings.Contains(f.Name(), grep) {
			device_id = f.Name()
		}
	}
	if len(device_id) == 0 {
		device_id = fallback_id
	}
	return device_id
}

func disable(payload []byte, state State) {
	err := os.WriteFile(
		fmt.Sprintf("%s/unbind", DRIVER_PATH),
		payload,
		0644,
	)
	if err != nil {
		log.Fatal(err)
	}
	write_json(state)
}

func enable(payload []byte, state State) {
	err := os.WriteFile(
		fmt.Sprintf("%s/bind", DRIVER_PATH),
		payload,
		0644,
	)
	if err != nil {
		log.Fatal(err)
	}
	write_json(state)
}

func main() {
	op := os.Args[1]
	state_file = read_json(STATE_JSON)
	var device_id string
	device_id = update_id(
		state_file.ID_GREP,
		state_file.ID,
	)
	fmt.Println(device_id)
	state_file.ID = device_id
        payload := []byte(device_id)
	if op == "restore" {
		if state_file.STATE == "bind" {
			enable(payload, state_file)
		} else {
			disable(payload, state_file)
		}
	}
	if op == "disable" {
		state_file.STATE = "unbind"
		disable(payload, state_file)
	}
	if op == "enable" {
		state_file.STATE = "bind"
		enable(payload, state_file)
	}
}
